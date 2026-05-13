create database miniss15;

use miniss15;


-- 1. TABLE USERS

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


-- 2. TABLE POSTS

CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_posts_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);

-- FULLTEXT SEARCH

ALTER TABLE posts
ADD FULLTEXT(content);

-- 3. TABLE COMMENTS

CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comments_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id),

    CONSTRAINT fk_comments_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id)
);


-- 4. TABLE LIKES

CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    post_id INT NOT NULL,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_post
    UNIQUE(user_id, post_id),

    CONSTRAINT fk_likes_users
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_likes_posts
    FOREIGN KEY (post_id)
    REFERENCES posts(post_id)
);


-- 5. TABLE FRIENDS

CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,

    user_id INT NOT NULL,
    friend_id INT NOT NULL,

    status VARCHAR(20)
    CHECK(status IN ('pending', 'accepted')),

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_not_self_friend
    CHECK(user_id <> friend_id),

    CONSTRAINT fk_friends_user
    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    CONSTRAINT fk_friends_friend
    FOREIGN KEY (friend_id)
    REFERENCES users(user_id)
);


-- 6. TABLE POST LOGS

CREATE TABLE post_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT,
    post_content TEXT,
    deleted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO users(username, password, email)
VALUES
('alice', '123456', 'alice@gmail.com'),
('bob', '123456', 'bob@gmail.com'),
('charlie', '123456', 'charlie@gmail.com');


INSERT INTO posts(user_id, content)
VALUES
(1, 'Hello everyone'),
(2, 'Learning MySQL'),
(3, 'Social network project');


INSERT INTO comments(post_id, user_id, content)
VALUES
(1, 2, 'Nice post'),
(1, 3, 'Very good');


INSERT INTO likes(user_id, post_id)
VALUES
(1, 2),
(2, 1),
(3, 1);

INSERT INTO friends(user_id, friend_id, status)
VALUES
(1, 2, 'accepted'),
(1, 3, 'pending');

-- chức năng 1  
create view view_user_info as
select user_id, username, email,created_at 
from users;

select * from view_user_info;


-- chức năng 2  
delimiter //
create procedure  sp_add_user (
in p_username varchar(50),
in p_password varchar(50),
in p_email  varchar(50)
)

begin
declare check_username int ;
declare check_email int;

select count(*) into check_username from users where username = p_username;
if check_username > 0 then select 'username đã tồn tại';
else 
select count(*) into check_email from users where email = p_email;
if check_email > 0 
then 
     signal sqlstate '45000'
     set message_text = 'email đã tồn tại';
	else 
    insert into users(username,password,email)
    values (p_username,p_password,p_email );
    end if;
end if;

end//

delimiter ;


call sp_add_user('thienduc','123','thienduc@gmail.com');



--  chức năng 3 
-- khi có người like bài viết 
DELIMITER //

CREATE TRIGGER tg_after_like_insert
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
    UPDATE posts 
    SET like_count = like_count + 1 
    WHERE post_id = NEW.post_id;
END //

delimiter ;

insert into likes(user_id,post_id)
values(1,3);


-- khi có người unlike bài viết 
DELIMITER //

CREATE TRIGGER tg_after_like_insert
AFTER delete ON likes
FOR EACH ROW
BEGIN
    UPDATE posts 
    SET like_count = like_count - 1 
    WHERE post_id = NEW.post_id;
END //

delimiter ;



-- chức năng 4

delimiter //

create procedure sp_user_activity_report()
begin
  select u.user_id, 
  u.username,
         count(distinct p.post_id) as total_posts,
         count(distinct l.like_id) as total_likes,
         count(distinct c.comment_id) as total_comments
         
  from users u
  
  
  left join posts p on u.user_id = p.user_id
  left join likes l on u.user_id = l.user_id
  left join comments c on u.user_id = c.user_id
  
  group by u.user_id, u.username;
end;


end // 

delimiter ;

-- chức năng 5 


-- sp_delete_user
delimiter //

create procedure sp_delete_user(
    in p_user_id int
)
begin

 

    start transaction;

    -- likes
    delete from likes
    where user_id = p_user_id
       or post_id in (
            select post_id
            from posts
            where user_id = p_user_id
       );

    -- comments
    delete from comments
    where user_id = p_user_id
       or post_id in (
            select post_id
            from posts
            where user_id = p_user_id
       );

    -- friends
    delete from friends
    where user_id = p_user_id
       or friend_id = p_user_id;

    --  posts
    delete from posts
    where user_id = p_user_id;

    --  user
    delete from users
    where user_id = p_user_id;

    commit;

end //

delimiter ;



-- Chức năng 6: Kiểm soát kết bạn 
-- Triển khai: tg_before_friend_insert.
-- Yêu cầu: Kiểm tra dữ liệu trước khi INSERT vào bảng friends. Dùng SIGNAL SQLSTATE để báo lỗi và chặn thao tác nếu vi phạm 1 trong 3 lỗi sau:
-- Tự kết bạn với chính mình (user_id = friend_id).
-- Trùng lặp dữ liệu (Cặp user_id - friend_id đã tồn tại).
-- Lời mời đảo chiều (B gửi cho A trong khi hệ thống đang ghi nhận A gửi cho B).

delimiter //

create trigger tg_before_friend_insert 
before insert on friends 
for each row 
begin
declare existed int ;
declare result int ;
select count(*) into existed from friends where user_id = new.user_id and friend_id = new.friend_id ;
select count(*) into result from friends where user_id = new.friend_id and friend_id = new.user_id;

-- user_id = 1 ,friend_id = 2 là (cặp 1,2) tương đương cặp 2,1   
 
  
if new.user_id = new.friend_id then
	signal sqlstate '45000'
	set message_text = 'lỗi ko ddc kết bạn với chính mình ';
elseif  existed > 0 then 
    signal sqlstate '45000'
    set message_text = 'bạn đã gửi kết bạn cho ng này r ';
    
elseif result > 0 then 
      signal sqlstate '45000'
    set message_text = 'lỗi lời mời của bạn bị đảo chiều ';
end if;

end //

delimiter ;

insert into friends (user_id, friend_id)
values (2,3);







 








