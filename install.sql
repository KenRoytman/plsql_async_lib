
whenever sqlerror exit -1 rollback;

grant execute on dbms_crypto to &&install_user.
/
grant execute on dbms_lock to &&install_user.
/
grant execute on dbms_alert to &&install_user.
/
grant execute on dbms_scheduler to &&install_user.
/

grant create job to &&install_user.
/
grant create table to &&install_user.
/
grant create procedure to &&install_user.
/
grant select any dictionary to &&install_user.
/

grant alter system to &&install_user.
/
