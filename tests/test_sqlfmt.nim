import unittest
import ba0f3/sqlfmt

suite "SQL query parameter substitution":
  test "Basic Substitution":
    check sqlfmt("SELECT * FROM users WHERE username = %s", "john_doe").string == "SELECT * FROM users WHERE username = 'john_doe'"

  test "Multiple Parameters":
    check sqlfmt("SELECT * FROM orders WHERE customer_id = %d AND status = %s", 123, "shipped").string == "SELECT * FROM orders WHERE customer_id = 123 AND status = 'shipped'"

  test "String Escaping":
    check sqlfmt("SELECT * FROM users WHERE username = %s", "O'Reilly").string == "SELECT * FROM users WHERE username = 'O''Reilly'"

  test "Integer Parameters":
    check sqlfmt("SELECT * FROM products WHERE price > %d", 100).string == "SELECT * FROM products WHERE price > 100"

  test "SQL Injection Prevention":
    check sqlfmt("SELECT * FROM users WHERE username = %s", "'; DROP TABLE users; --").string == "SELECT * FROM users WHERE username = '''; DROP TABLE users; --'"

  test "Boolean Parameters":
    var isActive = false
    check sqlfmt("SELECT * FROM features WHERE is_active = %b", true).string == "SELECT * FROM features WHERE is_active = 1"
    check sqlfmt("SELECT * FROM features WHERE is_active = %b", false).string == "SELECT * FROM features WHERE is_active = 0"
    check sqlfmt("SELECT * FROM features WHERE is_active = %b", isActive).string == "SELECT * FROM features WHERE is_active = 0"

  test "Float Parameters":
    check sqlfmt("SELECT * FROM products WHERE price = %f", 19.99).string == "SELECT * FROM products WHERE price = 19.99"
    check sqlfmt("SELECT * FROM measurements WHERE value = %f", 1234567890.123456).string == "SELECT * FROM measurements WHERE value = 1234567890.123456"


  test "Special Characters":
    check sqlfmt("SELECT * FROM comments WHERE comment_text = %s", "%_escape_test_").string == "SELECT * FROM comments WHERE comment_text = '%_escape_test_'"

  test "Empty Parameters":
    check sqlfmt("SELECT * FROM logs WHERE log_message = %s", "").string == "SELECT * FROM logs WHERE log_message = ''"


#check sqlfmt("").string == ""SELECT * FROM logs WHERE log_message = ?