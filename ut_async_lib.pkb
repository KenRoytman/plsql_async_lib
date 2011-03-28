create or replace package body ut_async_lib
is

  --{{ function reg_alert_count

  function reg_alert_count
    return integer
  is
    l_count  integer;
  begin

    select count(*)
      into l_count
    from sys.dbms_alert_info
    where sid = async_lib.alert_info_sid();

    return l_count;
  end reg_alert_count;

  --}}

  --{{ procedure ut_setup

  procedure ut_setup
  is
  begin
      execute immediate q'#
        create table ut_async_lib_tab ( c1 number )
      #';

      execute immediate q'#
        create or replace procedure ut_async_lib_proc(p_in in number)
        is
        begin
          insert into ut_async_lib_tab values (p_in); 

          commit;

        end ut_async_lib_proc;
        #';
  end ut_setup;

  --}}

  --{{ procedure ut_teardown

  procedure ut_teardown
  is
  begin
      execute immediate 'drop procedure ut_async_lib_proc'; 

      execute immediate 'drop table ut_async_lib_tab purge';
  end ut_teardown;

  --}} 

  --{{ procedure ut_is_async_active

  procedure ut_is_async_active
  is

    l_ret binary_integer;

    l_job_queue_proc number;
    l_string_val varchar2(32767);

    l_test_val boolean;
  begin

    -- save the original value for this parameter

    l_ret :=
      dbms_utility.get_parameter_value (
        parnam => 'job_queue_processes'
      , intval => l_job_queue_proc
      , strval => l_string_val
      );

    execute immediate 'begin set_job_queue_processes(0); end;';

    l_test_val := async_lib.is_async_active();
  
    utassert.eq (
      msg_in => 'JOB_QUEUE_PROCESSES is less than or equal to 0'
    , check_this_in => l_test_val
    , against_this_in => false
    );    

    execute immediate 'begin set_job_queue_processes(100); end;';

    l_test_val := async_lib.is_async_active();

    utassert.eq (
      msg_in => 'JOB_QUEUE_PROCESSES is greater than 0'
    , check_this_in => l_test_val
    , against_this_in => true
    );    

    execute immediate
      'begin set_job_queue_processes('||l_job_queue_proc||'); end;';

  exception
    when others then
      execute immediate
        'begin set_job_queue_processes('||l_job_queue_proc||'); end;';

        raise;

  end ut_is_async_active;

  --}}

  --{{ procedure ut_run

  procedure ut_run
  is
    l_row_count number;

    procedure setup
    is
    begin
      null;
    end setup;

    procedure teardown
    is
    begin
      execute immediate 'delete ut_async_lib_tab';

      commit;

      async_lib.reset_state();
    end teardown;

  begin

    setup();

    async_lib.run('ut_async_lib_proc(1);');

    async_lib.wait();

    execute immediate
    q'#
        select count(*)
        from ut_async_lib_tab
    #' into l_row_count;

    utassert.eq (
      msg_in => 'running a procedure that performs dml'
    , check_this_in => l_row_count
    , against_this_in => 1
    );    

    teardown();

  exception
    when others then
      teardown();

      raise;

  end ut_run;

  --}}

  --{{ procedure ut_wait

  procedure ut_wait
  is
    l_job_map   async_lib.t_job_map;
    l_res_tab   async_lib.t_async_res_tab;

    l_tmp       async_lib.st_job_name;

    procedure setup
    is
    begin
      null;
    end setup;

    procedure teardown
    is
    begin
      execute immediate 'delete ut_async_lib_tab';

      commit;

      async_lib.reset_state();
    end teardown;
  begin

    setup();

    async_lib.run('ut_async_lib_proc(1);');
    async_lib.run('ut_async_lib_proc(2);');
    async_lib.run('ut_async_lib_proc(3);');
    async_lib.run('ut_async_lib_proc(4);');

    l_job_map := async_lib.job_map();

    utassert.eq
    (
      msg_in => 'job map count vs. constant before wait()'
    , check_this_in => l_job_map.count
    , against_this_in => 4
    );

    utassert.eq
    (
      msg_in =>
        'job map count vs. sys.dbms_alert_info ' ||
        'before wait()'
    , check_this_in => l_job_map.count
    , against_this_in => reg_alert_count()
    );

    async_lib.wait();

    l_job_map := async_lib.job_map();

    utassert.eq
    (
      msg_in => 'job map count vs. constant after wait()'
    , check_this_in => l_job_map.count
    , against_this_in => 0
    );

    utassert.eq
    (
      msg_in =>
        'job map count vs. sys.dbms_alert_info ' ||
        'after wait()'
    , check_this_in => l_job_map.count
    , against_this_in => reg_alert_count()
    );

    async_lib.reset_state();

    async_lib.run('ut_async_lib_proc(1/0);');

    l_job_map := async_lib.job_map();

    utassert.eq
    (
      msg_in =>
        'error job map count vs. constant for ' ||
        '1/0 exception before wait()'
    , check_this_in => l_job_map.count
    , against_this_in => 1 
    );

    utassert.eq
    (
      msg_in => 'error job map count vs. sys.dbms_alert_info '||
                'for 1/0 exception before wait()'
    , check_this_in => l_job_map.count
    , against_this_in => reg_alert_count()
    );

    async_lib.wait(l_res_tab);

    l_tmp := l_res_tab.first();

    utassert.this
    (
      msg_in => 'async error message for 1/0 exception'
    , check_this_in =>
          (
            (l_res_tab(l_tmp).return_status = -1) and
            (l_res_tab(l_tmp).error_code = 'ORA-1476')
          )
    );

    -- 1. test message communication when a job raises an exception

    -- 2. test situation where an alert is signaled but is not
    --    in async_lib's job vector.
    --
    --    this can happen with the following order of events:
    --      async_lib.run(...);
    --      async_lib.reset_state();
    --      async_lib.run(...);
    --      async_lib.wait();

    teardown();

  exception
    when others then
      teardown();

      raise;

  end ut_wait;

  --}}

  --{{ procedure ut_reset_state

  procedure ut_reset_state
  is
    l_row_count pls_integer;

    l_job_map   async_lib.t_job_map;

    procedure setup
    is
    begin
      execute immediate q'#
        create or replace procedure ut_async_lib_reset
        is
        begin
          dbms_lock.sleep(3);  
        end ut_async_lib_reset;
        #';

    end setup;

    procedure teardown
    is
    begin
      execute immediate 'drop procedure ut_async_lib_reset';
    end teardown;

  begin

    setup();

    async_lib.run('ut_async_lib_reset();');
    async_lib.reset_state();

    l_job_map := async_lib.job_map(); 

    select count(*)
      into l_row_count
    from sys.dbms_alert_info
    where sid = async_lib.alert_info_sid();

    utassert.eq
    (
      msg_in => 'testing registered alerts.  wait() not called.'
    , check_this_in => l_row_count
    , against_this_in => 0
    );

    utassert.eq
    (
      msg_in => 'testing async_lib job map.  wait() not called.'
    , check_this_in => l_job_map.count
    , against_this_in => 0
    );

    teardown();

  exception
    when others then
      teardown();
  
      raise;

  end ut_reset_state;

  --}}

  --{{ procedure ut_alert_info_sid

  procedure ut_alert_info_sid
  is

    l_row_count pls_integer;

    procedure setup
    is
    begin
      execute immediate q'#
        create or replace procedure ut_async_lib_sid
        is
        begin
          dbms_lock.sleep(1);
        end ut_async_lib_sid;
        #';

    end setup;

    procedure teardown
    is
    begin
      execute immediate 'drop procedure ut_async_lib_sid';
      async_lib.reset_state();
    end teardown;
  begin
    setup();

    async_lib.run('ut_async_lib_sid();');
    async_lib.run('ut_async_lib_sid();');
    async_lib.run('ut_async_lib_sid();');

    select count(*)
      into l_row_count
    from sys.dbms_alert_info
    where sid = async_lib.alert_info_sid();

    utassert.eq
    (
      msg_in => 'testing registered alerts in sys.dbms_alert_info'
    , check_this_in => l_row_count
    , against_this_in => 3
    );

    teardown();
  exception
    when others then
      teardown();

      raise;

  end ut_alert_info_sid;

  --}}

  --{{ procedure ut_msg_serialization

  procedure ut_msg_serialization
  is

    l_msg_serialized async_lib.st_msg;
    l_msg_deserialized async_lib.t_async_res_rec;
    l_test async_lib.t_async_res_rec;

  begin

    l_msg_deserialized.return_status := 0;
    l_msg_deserialized.error_code := '-123456';

    l_msg_serialized := async_lib.serialize_msg(l_msg_deserialized);

    l_test := async_lib.deserialize_msg(l_msg_serialized);

    utassert.eq
    (
      msg_in => 'return status serialization '
    , check_this_in => l_test.return_status
    , against_this_in => 0
    );

    utassert.eq
    (
      msg_in => 'error code serialization '
    , check_this_in => l_test.error_code
    , against_this_in => 'ORA-123456'
    );

     
  end ut_msg_serialization;

  --}}

  procedure test
  is
  begin
    utplsql.test(package_in => 'async_lib', recompile_in => false);  
  end test;

end ut_async_lib;
/
