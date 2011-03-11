create or replace package body ut_async_lib
is

  procedure ut_setup
  is
  begin
    null;
  end ut_setup;

  procedure ut_teardown
  is
  begin
    null;
  end ut_teardown;

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
      msg_in => 'JOB_QUEUE_PROCESSES is <= 0'
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

  procedure ut_run
  is
    l_row_count number;


    procedure setup
    is
    begin

      execute immediate q'#
        create table ut_run_tab ( c1 number )
      #';

      execute immediate q'#
        create or replace procedure ut_run_proc
        is
        begin
          insert into ut_run_tab values (1); 

          commit;
        end ut_run_proc;
        #';

    end setup;

    procedure teardown
    is
    begin

      execute immediate 'drop procedure ut_run_proc'; 

      execute immediate 'drop table ut_run_tab purge';
    end teardown;

  begin

    setup();

    async_lib.run('ut_run_proc();');

    execute immediate
    q'#
        select count(*)
        from ut_run_tab
    #' into l_row_count;

    utassert.eq (
      msg_in => 'running a procedure that performs dml'
    , check_this_in => l_row_count
    , against_this_in => 1
    );    

    teardown();

    -- test that a scheduled proc runs!
    -- what happens when a function is passed in
    --

  end ut_run;

end ut_async_lib;
/
