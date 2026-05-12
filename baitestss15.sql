create database baitest;

use baitest;


create table students (
student_id varchar (5) primary key ,
full_name varchar(50) not null,
total_debt decimal(10,2) default 0 
);

create table subjects(
subject_id varchar(5) primary key ,
subject_name varchar(50) not null ,
credits int check (credits> 0)
);


create table grades (
student_id  varchar(5)primary key , 
subject_id varchar(5) ,
score decimal(4,2)check (score between 0 and 10), 
foreign key (student_id) references students (student_id),
foreign key (subject_id) references subjects (subject_id)

);


create table grade_log(
log_id int primary key auto_increment,
student_id varchar(5),
old_score decimal(4,2),
new_score decimal(4,2),
change_date datetime default current_timestamp,
foreign key (student_id) references students (student_id)
);


-- cau1 phan a 
delimiter //
create trigger tg_check_score
before insert  on grades
for each row 
begin 
  if new.score < 0 then set new.score = 0;
  elseif new.score > 0 then set new.score = 10;
  end if;

end //

delimiter ;

-- cau 2  phan a 

delimiter //
create procedure update_students(
 in s_student_id varchar(5) ,
 in s_full_name varchar (50)

)
begin 
start transaction;

begin  
  insert into students (student_id, full_name)
  values (s_student_id,s_full_name );
  
  update students 
  set total_debt = 5000000
  where student_id = s_student_id;
  commit;
end;

end //

delimiter ;

call update_students ('SV02','Ha Bich Ngoc');




-- cau 1 phan b 
delimiter //

create trigger tg_log_grade_update 
after insert on grades 
for each row 
begin 
  insert into grade_log (student_id, old_score,new_score, change_date)
  values (student_id, old_score,new_score, change_date);
end // 
delimiter ;


-- cau2 phan b 
delimiter //
create procedure update_students(
 in s_student_id varchar(5) ,
 in s_full_name varchar (50)

)
begin 
start transaction;

begin  
 
  commit;
end;

end //

delimiter ;







