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
  subtype st_msg is varchar2(1800);
  subtype st_job_name is varchar2(64);
  subtype st_job_error_trc is varchar2(2048);

  type t_job_map is table of st_job_name index by st_alert;

  type t_async_res_rec is record (
    return_status integer
  , error_code  varchar2(32)
  , error_stack varchar2(1024)
  , stack_trace varchar2(2048)
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

  function serialize_msg (p_message in t_async_res_rec)
    return st_msg;

  function deserialize_msg ( p_message in st_msg )
    return t_async_res_rec;
    
  procedure reset_state;

  function alert_info_sid
    return varchar2;

  function results_tab
    return t_async_res_tab;

  function job_map
    return t_job_map;

  procedure run (c in varchar2);

  procedure wait;

  --
  -- pl/sql function cannot return a pl/sql associative array
  -- in 10.2.0.3
  --

  procedure wait (async_results out async_lib.t_async_res_tab);

  procedure pretty_print_async_results;

  procedure pretty_print_async_results
    (p_async_results in async_lib.t_async_res_tab);

end async_lib;
/
