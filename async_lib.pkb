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
  g_job_vector        t_job_map;
  g_empty_job_vector  t_job_map;
  g_return_tab        t_async_res_tab;
  g_empty_return_tab  t_async_res_tab;
  
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

  --{{ function serialize_msg

  function serialize_msg ( p_message in t_async_res_rec )
    return st_msg
  is
    l_ret st_msg;
  begin

    l_ret :=
      replace
      (
        replace
        (
          '<rt>'||p_message.return_status||'</rt>'||
          '<c>ORA'||p_message.error_code||'</c>'||
          '<e>'
          ||p_message.error_stack||
          '</e><s>'
          ||p_message.stack_trace||
          '</s>'
        , chr(10)
        , ''
        )
      , chr(13)
      , ''
      );

    return l_ret;

  end serialize_msg;

  --}}

  --{{ function deserialize_msg

  function deserialize_msg ( p_message in st_msg )
    return t_async_res_rec
  is
    l_return t_async_res_rec;
  begin

    l_return.return_status :=
      to_number(
        substr
        (
          p_message
        , instr(p_message,'<rt>',1,1) + 4
        , instr(p_message,'</rt>',1,1) -
          instr(p_message,'<rt>',1,1) - 4
        )
      );


    l_return.error_code :=
      substr
      (
        p_message
      , instr(p_message,'<c>',1,1) + 3
      , instr(p_message,'</c>',1,1) - 
        instr(p_message,'<c>',1,1) - 3
      );

    l_return.error_stack :=
      substr
      (
        p_message
      , instr(p_message,'<e>',1,1) + 3
      , instr(p_message,'</e>',1,1) - 
        instr(p_message,'<e>',1,1) - 3
      );
      
     l_return.stack_trace :=
      substr
      (
        p_message
      , instr(p_message,'<s>',1,1) + 3
      , instr(p_message,'</s>',1,1) - 
        instr(p_message,'<s>',1,1) - 3
      );


    return l_return;

  end deserialize_msg;

  --}}

  --{{ function alert_info_sid

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
    g_return_tab := g_empty_return_tab;
    dbms_alert.removeall();
  end reset_state;

  --}}

  --{{ function results_tab
  function results_tab
    return t_async_res_tab
  is
  begin
    return g_return_tab;
  end results_tab;
  --}}  

  --{{ function job_map
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

    l_job_action := q'#
        declare
          l_message async_lib.t_async_res_rec;
          l_message_str async_lib.st_msg; 
        begin #'||c||q'#

          l_message.return_status := 0;

          dbms_alert.signal
          (
            name => '#'||l_alert||q'#'
          , message => async_lib.serialize_msg(l_message)
          );

          commit;

        exception
          when others then
            l_message.return_status := -1;
            l_message.error_code := sqlcode;
            l_message.error_stack := dbms_utility.format_error_stack();
            l_message.stack_trace := dbms_utility.format_error_backtrace();
       
            dbms_alert.signal
            (
              name => '#'||l_alert||q'#'
            , message => async_lib.serialize_msg(l_message)
            );
        end; #';
 
        
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
    l_alert   st_alert;
    l_msg     st_msg;
    l_status  integer;
  begin

    while (g_job_vector.count > 0)
    loop

      dbms_alert.waitany
      (
        name    => l_alert
      , message => l_msg
      , status  => l_status
      );

      g_return_tab( g_job_vector(l_alert) ) :=
        async_lib.deserialize_msg(l_msg);

      g_job_vector.delete(l_alert);
      dbms_alert.remove(l_alert);

    end loop;

  end wait;

  --}}

  --{{ procedure wait overload #1

  procedure wait (async_results out async_lib.t_async_res_tab)
  is
  begin
    wait();

    async_results := g_return_tab;
  end wait;

  --}}

  --{{ procedure pretty_print_async_results
  procedure pretty_print_async_results
  is
  begin
    pretty_print_async_results(g_return_tab);
  end pretty_print_async_results;
  --}}

  --{{ procedure pretty_print_async_results

  procedure pretty_print_async_results
    (p_async_results in async_lib.t_async_res_tab)
  is
    l_iter            st_job_name; 
  begin

    dbms_output.enable(1000000);

    l_iter := p_async_results.first(); 

    loop
      exit when ( l_iter is null );

      dbms_output.put_line( '<<job>>: '||l_iter);

      dbms_output.put_line
        ( '<<error stack>>: '||p_async_results(l_iter).error_code );

      dbms_output.put_line
        ( '<<stack trace>>: '||p_async_results(l_iter).stack_trace );

      l_iter := p_async_results.next(l_iter);
    end loop;

  end pretty_print_async_results;

  --}}

end async_lib;
/
