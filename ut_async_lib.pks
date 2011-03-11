create or replace package ut_async_lib
is

  procedure ut_setup;

  procedure ut_teardown; 

  procedure ut_is_async_active;

  procedure ut_run;

  procedure ut_wait;

  procedure test;

end ut_async_lib;
/
