-- Check if d_perfectmile_shipment_status_history exists and has data
-- This is the table we've been querying

-- 1. Check if our main table exists
SELECT
  'TABLE_EXISTS_CHECK' as check_type,
  table_schema,
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'heisenbergrefinedobjects'
  AND table_name = 'd_perfectmile_shipment_status_history';

-- 2. If not, check for similar shipment tables
SELECT
  'SHIPMENT_TABLES' as check_type,
  table_schema,
  table_name
FROM information_schema.tables
WHERE table_schema = 'heisenbergrefinedobjects'
  AND (table_name LIKE '%shipment%' OR table_name LIKE '%status%')
LIMIT 20;

-- 3. Check the global_dea table (might have shipment data)
SELECT
  'GLOBAL_DEA_SAMPLE' as check_type,
  COUNT(*) as total_rows
FROM heisenbergrefinedobjects.d_perfectmile_global_dea
WHERE DATE(event_datetime_utc) = CURRENT_DATE - INTERVAL '1 day'
LIMIT 1;

-- 4. Check columns in global_dea table
SELECT
  'GLOBAL_DEA_COLUMNS' as check_type,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'heisenbergrefinedobjects'
  AND table_name = 'd_perfectmile_global_dea'
LIMIT 20;