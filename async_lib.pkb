create or replace package body async_lib
is

  --------------------------------------------------------
  --<< todo >>--
  --------------------------------------------------------
  -- 1.  how to handle situation where job_queue_processes
  --     is reset to 0 in the middle of a session?
  --
  -- 2.  how to appropriately cleanup after an exception
  --     is raised if async vector has active signals
  --       
  --------------------------------------------------------

  -----------------------
  --<< private types >>--
  -----------------------

  -------------------------------
  --<< session scope globals >>--
  -------------------------------
  g_job_vector    t_job_map;
  g_empty_job_vector t_job_map;
  g_return_tab    t_async_res_tab;
  
  -------------------------
  --<< private modules >>--
  -------------------------

  --{{ procedure check_syntax
  
  procedure check_syntax(p_code in varchar2)
  is
    l_cursor integer;
  begin
    l_cursor := dbms_sql.open_cursor();
    dbms_sql.parse(l_cursor, p_code, dbms_sql.native);
    dbms_sql.close_cursor(l_cursor);
  exception
    when others then
      async_lib_err.err_job_syntax();
  end check_syntax;

  --}}

  --{{ function is_async_active

  function is_async_active
    return boolean
  is
    l_ret_ty  integer;
    l_ret_int integer;
    l_ret_str v$parameter.value%type;
  begin
    l_ret_ty :=
      dbms_utility.get_parameter_value (
        parnam => 'job_queue_processes'
      , intval => l_ret_int
      , strval => l_ret_str
      );

    if ( l_ret_int <= 0 )
    then
      return false;
    else
      return true;
    end if;

  end is_async_active; 

  --}}

  ------------------------
  --<< public modules >>--
  ------------------------

  --{{

  function alert_info_sid
    return varchar2
  is
    l_sid number;
    l_serial# number;
    l_instance_id number;
    l_ret varchar2(12);
  begin
    select
      lpad(to_char(sid, 'fmXXXX'), 4,'0') ||
      lpad(to_char(serial#, 'fmXXXX'),4,'0') ||
      lpad(to_char(sys_context('userenv','instance'), 'fmXXXX'),4,'0')
        into l_ret
    from v$session
    where sid = sys_context('userenv','sid');

    return l_ret;
  end alert_info_sid;

  --}}

  --{{ procedure reset_state

  procedure reset_state
  is
  begin
    g_job_vector := g_empty_job_vector;
    dbms_alert.removeall();
  end reset_state;

  --}}

  --{{ procedure job_map
  function job_map
    return t_job_map
  is
  begin
    return g_job_vector;
  end job_map;

  --}}

  --{{ procedure run
  --
  -- only supports procedures for now
  --

  procedure run (c in varchar2)
  is
    l_alert      st_alert;
    l_job_name   st_job_name;
    l_job_action varchar2(32767);
  begin

    if ( not is_async_active() )
    then
      async_lib_err.err_job_queue;
    end if;

    l_alert := rawtohex(dbms_crypto.randombytes(8));
    l_job_name := dbms_scheduler.generate_job_name(prefix => 'ASYNC$_');
    
    g_job_vector(l_alert) := l_job_name;
      
    dbms_alert.register(l_alert);

    l_job_action := 
        'begin'
        ||chr(10)||c||chr(10)||
        'dbms_alert.signal(name => '''
        ||l_alert||
        ''', message => '''');'
        ||chr(10)||
        'commit;'
        ||chr(10)||
        'exception'
        ||chr(10)||
        'when others then'
        ||chr(10)||         
        'dbms_alert.signal( name => '''
        ||l_alert||
        ''', message => '||
        'dbms_utility.format_error_stack()'
        ||'||chr(10)||'||
        'dbms_utility.format_error_backtrace()'
        ||');'||chr(10)||
        'end;';
        
    check_syntax(l_job_action);

    dbms_scheduler.create_job (
      job_name =>  g_job_vector(l_alert)
    , job_type => 'PLSQL_BLOCK'
    , job_action => l_job_action
    , enabled => true
    );

  exception
    when others then
      dbms_alert.remove(l_alert);
      g_job_vector.delete(l_alert);

      raise;

  end run;

  --}}

  --{{ procedure wait

  procedure wait
  is
    l_alert st_alert;
    l_message varchar2(32767); 
    l_status  integer;
  begin

    while (g_job_vector.count > 0)
    loop

      dbms_alert.waitany (
        name    => l_alert
      , message => l_message
      , status  => l_status
      );

      g_return_tab( g_job_vector(l_alert) ).job_status := -1;

      g_job_vector.delete(l_alert);

    end loop;

  end wait;

  --}}

end async_lib;
/
