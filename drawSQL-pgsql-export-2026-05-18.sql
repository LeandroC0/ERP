-- =========================================================
-- SISTEMA DE INVENTARIOS — BASE DE DATOS
-- PostgreSQL
-- Versión 2.0 — Mayo 2026
--
-- Cambios respecto a v1:
--   · Nueva tabla tax_type (tarifas de IVA según Ley 9635 CR)
--   · product: se agrega tax_type_id, is_exempt y trigger para final_price
--   · warehouse_stock: se agrega UNIQUE(warehouse_id, product_id)
--   · discount: se agrega CHECK(start_date < end_date)
--   · inventory_movement: se agrega user_id para auditoría
--   · Índices adicionales en sales, purchase y warehouse_stock
-- =========================================================


-- =========================================================
-- STATES
-- =========================================================

CREATE TABLE "state" (
    "id"   SERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL
);

ALTER TABLE "state"
ADD PRIMARY KEY("id");

ALTER TABLE "state"
ADD CONSTRAINT "state_name_unique" UNIQUE("name");


-- =========================================================
-- ROLES
-- =========================================================

CREATE TABLE "role" (
    "id"          SERIAL NOT NULL,
    "name"        VARCHAR(100) NOT NULL,
    "description" VARCHAR(255),
    "state_id"    INTEGER NOT NULL
);

ALTER TABLE "role"
ADD PRIMARY KEY("id");

ALTER TABLE "role"
ADD CONSTRAINT "role_name_unique" UNIQUE("name");

ALTER TABLE "role"
ADD CONSTRAINT "role_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- USERS
-- =========================================================

CREATE TABLE "users" (
    "id"         SERIAL NOT NULL,
    "name"       VARCHAR(150) NOT NULL,
    "lastname"   VARCHAR(150) NOT NULL,
    "email"      VARCHAR(255) UNIQUE NOT NULL,
    "password"   VARCHAR(255) NOT NULL,       -- almacenar siempre con bcrypt/Argon2
    "phone"      VARCHAR(50),
    "role_id"    INTEGER NOT NULL,
    "state_id"   INTEGER NOT NULL,
    "created_at" TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "users"
ADD PRIMARY KEY("id");

ALTER TABLE "users"
ADD CONSTRAINT "users_role_id_foreign"
FOREIGN KEY("role_id") REFERENCES "role"("id");

ALTER TABLE "users"
ADD CONSTRAINT "users_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- CLIENT
-- =========================================================

CREATE TABLE "client" (
    "id"       SERIAL NOT NULL,
    "name"     VARCHAR(150) NOT NULL,
	"id_type"	VARCHAR(150) NOT NULL,
	"id_number"	VARCHAR(150) NOT NULL,
    "lastname" VARCHAR(150),
    "email"    VARCHAR(255),
    "phone"    VARCHAR(50),
    "address"  VARCHAR(255),
    "state_id" INTEGER NOT NULL
);

ALTER TABLE "client"
ADD PRIMARY KEY("id");

ALTER TABLE "client"
ADD CONSTRAINT "client_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- SUPPLIER
-- =========================================================

CREATE TABLE "supplier" (
    "id"           SERIAL NOT NULL,
    "company_name" VARCHAR(255) NOT NULL,
    "contact_name" VARCHAR(255),
    "email"        VARCHAR(255),
    "phone"        VARCHAR(50),
    "address"      VARCHAR(255),
    "state_id"     INTEGER NOT NULL
);

ALTER TABLE "supplier"
ADD PRIMARY KEY("id");

ALTER TABLE "supplier"
ADD CONSTRAINT "supplier_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- CATEGORY
-- =========================================================

CREATE TABLE "category" (
    "id"       SERIAL NOT NULL,
    "name"     VARCHAR(150) NOT NULL,
    "state_id" INTEGER NOT NULL
);

ALTER TABLE "category"
ADD PRIMARY KEY("id");

ALTER TABLE "category"
ADD CONSTRAINT "category_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- UNIT MEASURE
-- =========================================================

CREATE TABLE "unit_measure" (
    "id"       SERIAL NOT NULL,
    "name"     VARCHAR(100) NOT NULL,
    "symbol"   VARCHAR(20),
    "state_id" INTEGER NOT NULL
);

ALTER TABLE "unit_measure"
ADD PRIMARY KEY("id");

ALTER TABLE "unit_measure"
ADD CONSTRAINT "unit_measure_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- TAX TYPE 
-- Catálogo de tarifas de IVA según Ley 9635 de Costa Rica.
-- Centraliza los porcentajes para evitar valores arbitrarios
-- en los productos.
-- =========================================================

CREATE TABLE "tax_type" (
    "id"          SERIAL NOT NULL,
    "name"        VARCHAR(100) NOT NULL,          -- ej. 'IVA General 13%'
    "rate"        DECIMAL(5,2) NOT NULL,          -- ej. 13.00
    "description" VARCHAR(255),
    "state_id"    INTEGER NOT NULL
);

ALTER TABLE "tax_type"
ADD PRIMARY KEY("id");

ALTER TABLE "tax_type"
ADD CONSTRAINT "tax_type_name_unique" UNIQUE("name");

ALTER TABLE "tax_type"
ADD CONSTRAINT "tax_type_rate_check"
CHECK ("rate" >= 0 AND "rate" <= 100);

ALTER TABLE "tax_type"
ADD CONSTRAINT "tax_type_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");

-- Datos iniciales (descomentar y ejecutar después de insertar el estado 'activo' con id=1)
-- INSERT INTO "tax_type" ("name", "rate", "description", "state_id") VALUES
--   ('IVA General',                 13.00, 'Ley 9635, Art. 10 — tasa estándar',          1),
--   ('IVA Servicios Profesionales',  4.00, 'Ley 9635 — servicios médicos y similares',   1),
--   ('IVA Canasta Reducida',         2.00, 'Ley 9635 — canasta básica ampliada',          1),
--   ('IVA Canasta Básica',           1.00, 'Ley 9635 — canasta básica restringida',       1),
--   ('Exento',                       0.00, 'Ley 9635, Art. 9 — bienes y servicios exentos', 1);


-- =========================================================
-- PRODUCT
-- =========================================================
-- Cadena de cálculo de precios:
--   cost_price → (+profit_percentage%) → sale_price
--   sale_price → (+tax_rate%)          → final_price
--
-- sale_price y final_price se recalculan automáticamente
-- mediante el trigger trg_product_calc_prices (ver abajo).
-- =========================================================

CREATE TABLE "product" (
    "id"          SERIAL NOT NULL,

    "name"        VARCHAR(255) NOT NULL,
    "description" VARCHAR(500),
    "barcode"     VARCHAR(50) UNIQUE,
    "sku"         VARCHAR(100) UNIQUE,
    "category_id" INTEGER NOT NULL,
    "unit_id"     INTEGER NOT NULL,

    -- INVENTARIO
    "current_stock" INTEGER NOT NULL DEFAULT 0,
    "minimum_stock" INTEGER NOT NULL DEFAULT 0,
    "reorder_point" INTEGER NOT NULL DEFAULT 0,

    -- COSTOS Y PRECIOS
    "cost_price"        DECIMAL(12,2) NOT NULL DEFAULT 0,
    "profit_percentage" DECIMAL(5,2)  NOT NULL DEFAULT 30.00,
    "sale_price"        DECIMAL(12,2) NOT NULL DEFAULT 0,    -- sin IVA; calculado por trigger

    -- IVA  [MODIFICADO v2.0]
    "tax_type_id" INTEGER NOT NULL,                          -- FK al catálogo tax_type
    "tax_rate"    DECIMAL(5,2) NOT NULL DEFAULT 13.00,       -- copia desnormalizada para histórico en detalle
    "is_exempt"   BOOLEAN NOT NULL DEFAULT FALSE,            -- TRUE = exento Ley 9635 Art. 9

    -- PRECIO FINAL con IVA; mantenido por trigger
    "final_price" DECIMAL(12,2) NOT NULL DEFAULT 0,

    -- EXTRA
    "brand"     VARCHAR(150),
    "image_url" TEXT,

    "state_id"   INTEGER NOT NULL,
    "created_at" TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "product"
ADD PRIMARY KEY("id");

ALTER TABLE "product"
ADD CONSTRAINT "product_category_id_foreign"
FOREIGN KEY("category_id") REFERENCES "category"("id");

ALTER TABLE "product"
ADD CONSTRAINT "product_unit_id_foreign"
FOREIGN KEY("unit_id") REFERENCES "unit_measure"("id");

ALTER TABLE "product"
ADD CONSTRAINT "product_tax_type_id_foreign"       -- [NUEVO v2.0]
FOREIGN KEY("tax_type_id") REFERENCES "tax_type"("id");

ALTER TABLE "product"
ADD CONSTRAINT "product_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");

ALTER TABLE "product"
ADD CONSTRAINT "product_cost_price_check"
CHECK ("cost_price" >= 0);

ALTER TABLE "product"
ADD CONSTRAINT "product_profit_check"
CHECK ("profit_percentage" >= 0);

-- -------------------------------------------------------
-- TRIGGER: recalcula sale_price y final_price automáticamente
-- cada vez que se inserta o modifica cost_price,
-- profit_percentage o tax_rate.  [NUEVO v2.0]
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_product_calc_prices()
RETURNS TRIGGER AS $$
BEGIN
    NEW.sale_price  := ROUND(NEW.cost_price * (1 + NEW.profit_percentage / 100), 2);
    NEW.final_price := ROUND(NEW.sale_price  * (1 + NEW.tax_rate / 100), 2);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_product_calc_prices
BEFORE INSERT OR UPDATE OF "cost_price", "profit_percentage", "tax_rate"
ON "product"
FOR EACH ROW
EXECUTE FUNCTION fn_product_calc_prices();


-- =========================================================
-- DISCOUNT
-- =========================================================

CREATE TABLE "discount" (
    "id"            SERIAL NOT NULL,
    "name"          VARCHAR(150) NOT NULL,
    "discount_type" VARCHAR(50)  NOT NULL,     -- 'percent' | 'fixed'
    "value"         DECIMAL(12,2) NOT NULL,
    "start_date"    TIMESTAMP(0) WITHOUT TIME ZONE,
    "end_date"      TIMESTAMP(0) WITHOUT TIME ZONE,
    "state_id"      INTEGER NOT NULL
);

ALTER TABLE "discount"
ADD PRIMARY KEY("id");

ALTER TABLE "discount"
ADD CONSTRAINT "discount_type_check"
CHECK ("discount_type" IN ('percent', 'fixed'));

ALTER TABLE "discount"
ADD CONSTRAINT "discount_value_check"
CHECK ("value" >= 0);

ALTER TABLE "discount"
ADD CONSTRAINT "discount_percent_range_check"
CHECK ("discount_type" <> 'percent' OR "value" <= 100);

--coherencia de fechas de vigencia
ALTER TABLE "discount"
ADD CONSTRAINT "discount_dates_check"
CHECK (
    "start_date" IS NULL
    OR "end_date" IS NULL
    OR "start_date" < "end_date"
);

ALTER TABLE "discount"
ADD CONSTRAINT "discount_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- PAYMENT METHOD
-- =========================================================

CREATE TABLE "payment_method" (
    "id"       SERIAL NOT NULL,
    "name"     VARCHAR(100) NOT NULL,
    "state_id" INTEGER NOT NULL
);

ALTER TABLE "payment_method"
ADD PRIMARY KEY("id");

ALTER TABLE "payment_method"
ADD CONSTRAINT "payment_method_name_unique" UNIQUE("name");

ALTER TABLE "payment_method"
ADD CONSTRAINT "payment_method_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- WAREHOUSE
-- =========================================================

CREATE TABLE "warehouse" (
    "id"       SERIAL NOT NULL,
    "name"     VARCHAR(150) NOT NULL,
    "location" VARCHAR(255),
    "state_id" INTEGER NOT NULL
);

ALTER TABLE "warehouse"
ADD PRIMARY KEY("id");

ALTER TABLE "warehouse"
ADD CONSTRAINT "warehouse_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- WAREHOUSE STOCK
-- =========================================================

CREATE TABLE "warehouse_stock" (
    "id"           SERIAL NOT NULL,
    "warehouse_id" INTEGER NOT NULL,
    "product_id"   INTEGER NOT NULL,
    "stock"        INTEGER NOT NULL DEFAULT 0,
    "updated_at"   TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "warehouse_stock"
ADD PRIMARY KEY("id");

--evita duplicar la misma combinación bodega-producto
ALTER TABLE "warehouse_stock"
ADD CONSTRAINT "warehouse_stock_unique"
UNIQUE("warehouse_id", "product_id");

ALTER TABLE "warehouse_stock"
ADD CONSTRAINT "warehouse_stock_stock_check"
CHECK ("stock" >= 0);

ALTER TABLE "warehouse_stock"
ADD CONSTRAINT "warehouse_stock_warehouse_id_foreign"
FOREIGN KEY("warehouse_id") REFERENCES "warehouse"("id");

ALTER TABLE "warehouse_stock"
ADD CONSTRAINT "warehouse_stock_product_id_foreign"
FOREIGN KEY("product_id") REFERENCES "product"("id");


-- =========================================================
-- PURCHASE
-- =========================================================
-- total_amount = subtotal - discount_total + tax_total
-- =========================================================

CREATE TABLE "purchase" (
    "id"          SERIAL NOT NULL,

    "supplier_id" INTEGER NOT NULL,
    "user_id"     INTEGER NOT NULL,

    "purchase_date" TIMESTAMP(0) WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "subtotal"       DECIMAL(12,2) NOT NULL DEFAULT 0,
    "tax_total"      DECIMAL(12,2) NOT NULL DEFAULT 0,
    "discount_total" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "total_amount"   DECIMAL(12,2) NOT NULL DEFAULT 0,

    "state_id" INTEGER NOT NULL
);

ALTER TABLE "purchase"
ADD PRIMARY KEY("id");

ALTER TABLE "purchase"
ADD CONSTRAINT "purchase_amounts_check"
CHECK (
    "subtotal"       >= 0 AND
    "tax_total"      >= 0 AND
    "discount_total" >= 0 AND
    "total_amount"   >= 0
);

ALTER TABLE "purchase"
ADD CONSTRAINT "purchase_supplier_id_foreign"
FOREIGN KEY("supplier_id") REFERENCES "supplier"("id");

ALTER TABLE "purchase"
ADD CONSTRAINT "purchase_user_id_foreign"
FOREIGN KEY("user_id") REFERENCES "users"("id");

ALTER TABLE "purchase"
ADD CONSTRAINT "purchase_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- PURCHASE DETAIL
-- =========================================================
-- Fórmulas por línea:
--   subtotal     = quantity × unit_cost
--   tax_amount   = subtotal × (tax_rate / 100)
--   total_amount = subtotal + tax_amount
-- =========================================================

CREATE TABLE "purchase_detail" (
    "id"          SERIAL NOT NULL,

    "purchase_id" INTEGER NOT NULL,
    "product_id"  INTEGER NOT NULL,

    "quantity"    INTEGER NOT NULL CHECK ("quantity" > 0),

    "unit_cost"    DECIMAL(12,2) NOT NULL,

    "subtotal"     DECIMAL(12,2) NOT NULL,
    "tax_rate"     DECIMAL(5,2)  NOT NULL DEFAULT 13.00,   -- copia histórica al momento de la compra
    "tax_amount"   DECIMAL(12,2) NOT NULL DEFAULT 0,
    "total_amount" DECIMAL(12,2) NOT NULL,

    "state_id" INTEGER NOT NULL
);

ALTER TABLE "purchase_detail"
ADD PRIMARY KEY("id");

ALTER TABLE "purchase_detail"
ADD CONSTRAINT "purchase_detail_unit_cost_check"
CHECK ("unit_cost" >= 0);

ALTER TABLE "purchase_detail"
ADD CONSTRAINT "purchase_detail_purchase_id_foreign"
FOREIGN KEY("purchase_id") REFERENCES "purchase"("id");

ALTER TABLE "purchase_detail"
ADD CONSTRAINT "purchase_detail_product_id_foreign"
FOREIGN KEY("product_id") REFERENCES "product"("id");

ALTER TABLE "purchase_detail"
ADD CONSTRAINT "purchase_detail_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- SALES
-- =========================================================
-- total_amount = subtotal - discount_total + tax_total
-- =========================================================

CREATE TABLE "sales" (
    "id"             SERIAL NOT NULL,

    "invoice_number" VARCHAR(100),

    "user_id"    INTEGER NOT NULL,
    "client_id"  INTEGER NOT NULL,

    "sale_date" TIMESTAMP(0) WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    "subtotal"       DECIMAL(12,2) NOT NULL DEFAULT 0,
    "tax_total"      DECIMAL(12,2) NOT NULL DEFAULT 0,
    "discount_total" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "total_amount"   DECIMAL(12,2) NOT NULL DEFAULT 0,

    "payment_method_id" INTEGER,
    "discount_id"       INTEGER,

    "state_id" INTEGER NOT NULL
);

ALTER TABLE "sales"
ADD PRIMARY KEY("id");

ALTER TABLE "sales"
ADD CONSTRAINT "sales_amounts_check"
CHECK (
    "subtotal"       >= 0 AND
    "tax_total"      >= 0 AND
    "discount_total" >= 0 AND
    "total_amount"   >= 0
);

ALTER TABLE "sales"
ADD CONSTRAINT "sales_user_id_foreign"
FOREIGN KEY("user_id") REFERENCES "users"("id");

ALTER TABLE "sales"
ADD CONSTRAINT "sales_client_id_foreign"
FOREIGN KEY("client_id") REFERENCES "client"("id");

ALTER TABLE "sales"
ADD CONSTRAINT "sales_payment_method_id_foreign"
FOREIGN KEY("payment_method_id") REFERENCES "payment_method"("id");

ALTER TABLE "sales"
ADD CONSTRAINT "sales_discount_id_foreign"
FOREIGN KEY("discount_id") REFERENCES "discount"("id");

ALTER TABLE "sales"
ADD CONSTRAINT "sales_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- SALES DETAIL
-- =========================================================
-- Fórmulas por línea:
--   subtotal      = quantity × unit_price
--   base_iva      = subtotal - descuento_linea  (0 si no hay descuento)
--   tax_amount    = base_iva × (tax_rate / 100)
--   profit_amount = (unit_price - unit_cost) × quantity
--   total_amount  = base_iva + tax_amount
-- =========================================================

CREATE TABLE "sales_detail" (
    "id"       SERIAL NOT NULL,

    "sales_id"   INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,

    "quantity"   INTEGER NOT NULL CHECK ("quantity" > 0),

    "unit_price" DECIMAL(12,2) NOT NULL,   -- precio histórico al momento de la venta
    "unit_cost"  DECIMAL(12,2) NOT NULL,   -- costo histórico para calcular margen

    "subtotal"   DECIMAL(12,2) NOT NULL,

    "tax_rate"   DECIMAL(5,2)  NOT NULL DEFAULT 13.00,   -- tarifa histórica al momento de la venta
    "tax_amount" DECIMAL(12,2) NOT NULL DEFAULT 0,

    "profit_amount" DECIMAL(12,2) NOT NULL DEFAULT 0,

    "total_amount" DECIMAL(12,2) NOT NULL,

    "discount_id" INTEGER,

    "state_id" INTEGER NOT NULL
);

ALTER TABLE "sales_detail"
ADD PRIMARY KEY("id");

ALTER TABLE "sales_detail"
ADD CONSTRAINT "sales_detail_unit_price_check"
CHECK ("unit_price" >= 0);

ALTER TABLE "sales_detail"
ADD CONSTRAINT "sales_detail_sales_id_foreign"
FOREIGN KEY("sales_id") REFERENCES "sales"("id");

ALTER TABLE "sales_detail"
ADD CONSTRAINT "sales_detail_product_id_foreign"
FOREIGN KEY("product_id") REFERENCES "product"("id");

ALTER TABLE "sales_detail"
ADD CONSTRAINT "sales_detail_discount_id_foreign"
FOREIGN KEY("discount_id") REFERENCES "discount"("id");

ALTER TABLE "sales_detail"
ADD CONSTRAINT "sales_detail_state_id_foreign"
FOREIGN KEY("state_id") REFERENCES "state"("id");


-- =========================================================
-- INVENTORY MOVEMENT
-- =========================================================
-- Tabla de SOLO INSERCIÓN (INSERT).
-- No se permite UPDATE ni DELETE sobre estos registros.
--
-- reference_id apunta al id de purchase o sales según
-- movement_type (FK polimórfica, sin constraint formal).
--
-- Valores sugeridos para movement_type:
--   'purchase_in'   — entrada por compra confirmada
--   'purchase_void' — reversión por anulación de compra
--   'sale_out'      — salida por venta confirmada
--   'sale_void'     — reversión por anulación de venta
--   'adjustment'    — ajuste manual de inventario
-- =========================================================

CREATE TABLE "inventory_movement" (
    "id"           SERIAL NOT NULL,

    "product_id"   INTEGER NOT NULL,
    "warehouse_id" INTEGER NOT NULL,
    "user_id"      INTEGER NOT NULL,        

    "movement_type" VARCHAR(50) NOT NULL,

    "quantity"       INTEGER NOT NULL,
    "previous_stock" INTEGER NOT NULL,
    "new_stock"      INTEGER NOT NULL,

    "reference_id"   INTEGER,

    "created_at" TIMESTAMP(0) WITHOUT TIME ZONE
        NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE "inventory_movement"
ADD PRIMARY KEY("id");

ALTER TABLE "inventory_movement"
ADD CONSTRAINT "inventory_movement_new_stock_check"
CHECK ("new_stock" >= 0);

ALTER TABLE "inventory_movement"
ADD CONSTRAINT "inventory_movement_product_id_foreign"
FOREIGN KEY("product_id") REFERENCES "product"("id");

ALTER TABLE "inventory_movement"
ADD CONSTRAINT "inventory_movement_warehouse_id_foreign"
FOREIGN KEY("warehouse_id") REFERENCES "warehouse"("id");

ALTER TABLE "inventory_movement"
ADD CONSTRAINT "inventory_movement_user_id_foreign"   
FOREIGN KEY("user_id") REFERENCES "users"("id");


-- =========================================================
-- INDEXES
-- =========================================================

-- Búsqueda de productos
CREATE INDEX "idx_product_name"
ON "product"("name");

CREATE INDEX "idx_product_barcode"
ON "product"("barcode");

CREATE INDEX "idx_product_sku"                         
ON "product"("sku");

CREATE INDEX "idx_product_tax_type"                  
ON "product"("tax_type_id");

-- Ventas por fecha y cliente
CREATE INDEX "idx_sales_date"
ON "sales"("sale_date");

CREATE INDEX "idx_sales_client"                        
ON "sales"("client_id");

-- Compras por proveedor y fecha
CREATE INDEX "idx_purchase_supplier"                   
ON "purchase"("supplier_id");

CREATE INDEX "idx_purchase_date"                       
ON "purchase"("purchase_date");

-- Trazabilidad de inventario
CREATE INDEX "idx_inventory_product"
ON "inventory_movement"("product_id");

CREATE INDEX "idx_inventory_warehouse"                 
ON "inventory_movement"("warehouse_id");

CREATE INDEX "idx_inventory_created_at"                
ON "inventory_movement"("created_at");

-- Stock por bodega
CREATE INDEX "idx_warehouse_stock_product"             
ON "warehouse_stock"("product_id");