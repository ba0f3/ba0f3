CREATE TABLE users(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    password TEXT
);

INSERT INTO users (username, password) VALUES ('user1', 'pass1');
INSERT INTO users (username, password) VALUES ('user2', 'pass2');
INSERT INTO users (username, password) VALUES ('user3', 'pass3');