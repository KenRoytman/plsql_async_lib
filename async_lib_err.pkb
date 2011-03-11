create or replace package body async_lib_err
is

  procedure err_job_queue
  is
  begin
      raise_application_error
      (
        -20001
      , 'async_lib: job_queue_processes is less than or equal to 0'
      ,true
      );
  end err_job_queue;

end async_lib_err;
/
