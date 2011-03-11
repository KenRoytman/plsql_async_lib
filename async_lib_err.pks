create or replace package async_lib_err
is

  procedure err_job_syntax(msg in varchar2);
  
  procedure err_job_queue;

end async_lib_err;
/
