CREATE SCHEMA IF NOT EXISTS etl;

CREATE TABLE etl.company_raw (
  id SERIAL PRIMARY KEY,
  name text NOT NULL,
  clean_name TEXT,
  name_source TEXT NOT NULL,
  import_time TIMESTAMP NOT NULL
);
CREATE INDEX ix_etl_company_raw_name ON etl.company_raw (name, name_source);

CREATE FUNCTION etl.fn_clean_company_name(company_name TEXT)
RETURNS TEXT AS $$
BEGIN
  /* TODO: make cleaning function more robust */
  company_name = lower(company_name);
  RETURN company_name;
END; $$
LANGUAGE PLPGSQL;

/* For this trigger function, I also considered using a construction like: */
/*   col_val := row_to_json(NEW)->>col_name; */
/* but using dynamic sql doesn't seem to have any performance difference, and */
/* adds in a check against incorrect column names (will throw an error that */
/* column doesn't exist) */
CREATE OR REPLACE FUNCTION etl.trigger_update_company_raw()
RETURNS TRIGGER AS $$
DECLARE
  col_name TEXT;
  col_val TEXT;
BEGIN
  col_name := TG_ARGV[0];
  EXECUTE format('SELECT ($1).%I', col_name) INTO col_val USING NEW;
  IF col_val IS NOT NULL
    THEN
    IF NOT EXISTS (
      SELECT
      1
      FROM etl.company_raw
      WHERE name = col_val
        AND name_source = TG_NAME
    )
      THEN
      INSERT INTO etl.company_raw (name, clean_name, name_source, import_time)
      VALUES (
        col_val,
        etl.fn_clean_company_name(col_val),
        TG_NAME,
        NOW()
      );
    END IF; -- Not Exists name = col_val
  END IF; -- col_val is not null

  RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;

