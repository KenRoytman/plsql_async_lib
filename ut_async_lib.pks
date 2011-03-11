create or replace package ut_async_lib
is

  procedure ut_setup;

  procedure ut_teardown; 

  procedure ut_is_async_active;

  procedure ut_run;

end ut_async_lib;
/
