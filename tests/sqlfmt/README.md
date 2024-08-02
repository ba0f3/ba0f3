# Testing sqlfmt agains sqlmap

### Test get user by id
```shell
sqlmap --ignore-code 400 --risk 3 --level 5 -u "http://localhost:8080/get?id=1" --dbs
```

### Test search by username
```shell
sqlmap --risk 3 --level 5 -u "http://localhost:8080/search?username=user1" --dbs
```

### Test login
```shell
sqlmap --risk 3 --level 5 -u "http://localhost:8080/login" --data="{'username': 'user', 'password': 'pass'}" --level 5 --risk 3 -f --banner --ignore-code 401 --dbms='sqlite'
```