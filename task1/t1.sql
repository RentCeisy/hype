/** Пишу сразу с созданием индексов, хотя искренне верю что индексы нужно добавлять при обнаружении медленных запросов и при невозможности ускорить другим путем **/
/**
 * Таблица users
 */
create table users
(
    id       bigint unsigned auto_increment primary key,
    name     varchar(255) not null,
    email    varchar(255) not null,
    password varchar(255) not null,
    unique index (email), /* Можно создать индекс по почте, чтоб быстрее происходила авторизация пользователя */
    constraint users_email_unique unique (email)
)
    collate = utf8mb4_unicode_ci;

/**
 * Таблица news
 * Ограничение на 243 байта
 * category_id (у новости всего одна категория)
 * Храню здесь сразу общее число лайков, чтоб каждый раз при доставании новости не считать count likes
 */
create table news
(
    id          bigint unsigned auto_increment primary key,
    user_id     bigint unsigned not null,
    category_id bigint unsigned not null,
    title       varchar(255)    not null,
    description varchar(242)    not null,
    like_count  int unsigned             default 0 not null,
    created_at  timestamp       not null default current_timestamp,
    updated_at  timestamp       not null default current_timestamp ON UPDATE current_timestamp,
    index (category_id, created_at), /* Можно сделать индекс по категории и по дате так как мы будем доставать только последние свежие новости (соблюдаем порядок присвоения индекса) */
    constraint news_user_id_foreign
        foreign key (user_id) references users (id),
    constraint news_category_id_foreign
        foreign key (category_id) references categories (id)
)
    collate = utf8mb4_unicode_ci;

/**
 * Таблица category
 */
create table categories
(
    id   bigint unsigned auto_increment primary key,
    name varchar(255) not null
)
    collate = utf8mb4_unicode_ci;

/**
 * Таблица news_likes (При удалении новости лайки удаляются)
 */
create table news_likes
(
    user_id bigint unsigned not null,
    news_id bigint unsigned not null,
    index (news_id), /* можно поставить индекс так как будем искать по новости кто оценил пост*/
    constraint news_likes_user_id_foreign
        foreign key (user_id) references users (id),
    constraint news_likes_news_id_foreign
        foreign key (news_id) references news (id)
            on delete cascade
)
    collate = utf8mb4_unicode_ci;

/**
 * Запрос: Достать пост по категории
 */
SELECT n.id, n.user_id, u.name, c.name, n.description, n.like_count
FROM news n
         LEFT JOIN categories c ON c.id = n.category_id
         LEFT JOIN users u ON u.id = n.user_id
WHERE n.category_id = :category_id
ORDER BY n.created_at;

/**
 * Запрос: Достать последние 10 новостей
 */
SELECT n.id, n.user_id, u.name, c.name, n.description, n.like_count
FROM news n
         LEFT JOIN categories c ON c.id = n.category_id
         LEFT JOIN users u ON u.id = n.user_id
ORDER BY n.created_at
LIMIT 10;

/**
* Запрос: Достать пользователей оценивших пост ()
*/
SELECT nl.news_id, nl.user_id, u.name
FROM news_likes nl
         LEFT JOIN users u ON u.id = nl.user_id
WHERE nl.news_id = :news_id;

/**
* Запрос: Добавить лайк
*/
START TRANSACTION;
UPDATE news
SET like_count = like_count + 1
WHERE user_id = :userid;

INSERT INTO news_likes (user_id, news_id) VALUES (:user_id, :news_id);
COMMIT;

/**
* Запрос: Убрать лайк
*/
START TRANSACTION;
UPDATE news
SET like_count = like_count - 1
WHERE user_id = :userid;

DELETE FROM news_likes WHERE news_id = :news_id AND user_id = :user_id;
COMMIT;

