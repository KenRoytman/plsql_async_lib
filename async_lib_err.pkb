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

  procedure err_job_syntax(msg in varchar2)
  is
  begin
      raise_application_error
      (
        -20002
      , 'async_lib: invalid syntax!'||chr(10)||msg
      ,true
      );
  end err_job_syntax;

end async_lib_err;
/
