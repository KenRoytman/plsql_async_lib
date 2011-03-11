create or replace package async_lib
is

  --@sys_privs (
  --  (create job),
  --  (create any job),
  --)
  

  --@object_privs (
  --  (execute, dbms_alert),
  --  (execute, dbms_crypto),
  --  (execute, dbms_scheduler)
  --)

  --@roles ( select_catalog_role )

  ----------------------------
  --<< library exceptions >>--
  ----------------------------

  ---------------------------
  --<< library constants >>--
  ---------------------------
  g_procedure  constant pls_integer := 0; 
  g_function   constant pls_integer := 1;
  g_query      constant pls_integer := 2;
  g_query_dml  constant pls_integer := 3;
  g_query_ddl  constant pls_integer := 4;

  ----------------------
  --<< custom types >>--
  ----------------------
  subtype st_run is pls_integer range 0 .. 4;
  subtype st_alert is varchar2(32);
  subtype st_job_name is varchar2(64);
  subtype st_job_error_trc is varchar2(2048);

  type t_job_map is table of st_job_name index by st_alert;

  type t_async_res_rec is record (
    job_status    integer  
  , alert_name    st_alert
  , error_trace   st_job_error_trc
  );

  type t_async_res_tab is table of t_async_res_rec
    index by st_job_name;

  ----------------------------------------
  --<< private modules >>--
  --<< public in dev for unit testing >>--
  ----------------------------------------

  procedure check_syntax(p_code in varchar2);

  function is_async_active
      return boolean;

  ---------------------------
  --<< public modules >>--
  ---------------------------

  procedure reset_state;

  function job_map
    return t_job_map;

  procedure run (c in varchar2);

  procedure wait;

end async_lib;
/
