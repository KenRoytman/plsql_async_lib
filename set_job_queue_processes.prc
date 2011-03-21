create or replace procedure &&dba_user..set_job_queue_processes
(
  p_job_queue_length in integer
)
authid definer
is
begin

  if ( p_job_queue_length < 0)
  then
    execute immediate 'alter system set job_queue_processes = 0';
  elsif ( p_job_queue_length >= 0 )
  then
    execute immediate 'alter system set job_queue_processes = '
    || p_job_queue_length;
  end if;

end set_job_queue_processes;
/
