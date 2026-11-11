/**
 * SOQLWhereClauseParser - A utility class for parsing WHERE clauses in SOQL queries
 */
public class SOQLWhereClauseParser {

  // ===== DATA MODELS =====

  /**
   * Represents a WHERE clause in a SOQL query
   */
  public class WhereClause {
    public Condition left { get; set; }
    public String operator { get; set; } // AND, OR
    public WhereClause right { get; set; }

    public WhereClause(Condition left) {
      this.left = left;
    }

    public WhereClause(Condition left, String operator, WhereClause right) {
      this.left = left;
      this.operator = operator;
      this.right = right;
    }
  }

  /**
   * Represents a condition in a WHERE clause
   */
  public class Condition {
    public String field { get; set; }
    public String operator { get; set; } // =, !=, <, >, LIKE, IN, etc.
    public String value { get; set; }
    public String literalType { get; set; }

    public Condition(String field, String operator, String value) {
      this.field = field;
      this.operator = operator;
      this.value = value;
      this.literalType = determineLiteralType(value);
    }

    private String determineLiteralType(String value) {
      if (value == null) return 'NULL';
      if (value.startsWith('\'') && value.endsWith('\'')) return 'STRING';
      if (value.equalsIgnoreCase('true') || value.equalsIgnoreCase('false')) return 'BOOLEAN';
      if (value.isNumeric()) return 'NUMBER';
      if (value.startsWith('LAST_N_') || value.startsWith('NEXT_N_') ||
        value.startsWith('THIS_') || value.startsWith('NEXT_') ||
        value.startsWith('LAST_')) return 'DATE_LITERAL';
      return 'STRING';
    }
  }

  // ===== PARSING FUNCTIONALITY =====

  /**
   * Parse a WHERE clause string into a WhereClause object
   * @param whereString The WHERE clause string (without the "WHERE" keyword)
   * @return WhereClause The parsed WHERE clause
   */
  public static WhereClause parseWhereClause(String whereString) {
    // Handle null or empty input
    if (whereString == null || whereString.trim() == '') {
      return new WhereClause(new Condition('Id', '=', 'null'));
    }
    
    whereString = whereString.trim();
    
    try {
      // Handle parenthesized expressions at the top level
      if (whereString.startsWith('(') && balancedParentheses(whereString)) {
        // Check if the entire string is wrapped in parentheses
        if (findMatchingClosingParenthesis(whereString, 0) == whereString.length() - 1) {
          // Remove the outer parentheses and parse the content
          return parseWhereClause(whereString.substring(1, whereString.length() - 1).trim());
        }
      }
      
      // Find the top-level logical operator (AND/OR) with proper parentheses handling
      Integer andIndex = findTopLevelOperator(whereString, ' AND ');
      if (andIndex != -1) {
        String leftPart = whereString.substring(0, andIndex).trim();
        String rightPart = whereString.substring(andIndex + 5).trim(); // 5 is length of " AND "
        
        WhereClause leftClause = parseWhereClause(leftPart);
        WhereClause rightClause = parseWhereClause(rightPart);
        
        return new WhereClause(leftClause.left, 'AND', rightClause);
      }
      
      Integer orIndex = findTopLevelOperator(whereString, ' OR ');
      if (orIndex != -1) {
        String leftPart = whereString.substring(0, orIndex).trim();
        String rightPart = whereString.substring(orIndex + 4).trim(); // 4 is length of " OR "
        
        WhereClause leftClause = parseWhereClause(leftPart);
        WhereClause rightClause = parseWhereClause(rightPart);
        
        return new WhereClause(leftClause.left, 'OR', rightClause);
      }
      
      // If no logical operators found, it's a simple condition
      return new WhereClause(parseCondition(whereString));
    }
    catch (Exception e) {
      throw new SOQLParserException('Error parsing WHERE clause: ' + e.getMessage());
    }
  }
  
  /**
   * Find the index of a top-level operator in a string, respecting parentheses
   * @param str The string to search in
   * @param operator The operator to find
   * @return Integer The index of the operator, or -1 if not found
   */
  private static Integer findTopLevelOperator(String str, String operator) {
    Integer depth = 0;
    
    // Start from the beginning to prioritize left-to-right evaluation
    for (Integer i = 0; i <= str.length() - operator.length(); i++) {
      if (i < str.length() && str.substring(i, i+1) == '(') {
        depth++;
      } else if (i < str.length() && str.substring(i, i+1) == ')') {
        depth--;
      } else if (depth == 0 && i + operator.length() <= str.length()) {
        // Check if we found the operator at the current position
        if (str.substring(i, i + operator.length()) == operator) {
          return i;
        }
      }
    }
    
    return -1;
  }
  
  /**
   * Check if a string has balanced parentheses
   * @param str The string to check
   * @return Boolean True if the parentheses are balanced
   */
  private static Boolean balancedParentheses(String str) {
    Integer depth = 0;
    
    for (Integer i = 0; i < str.length(); i++) {
      if (i < str.length() && str.substring(i, i+1) == '(') {
        depth++;
      } else if (i < str.length() && str.substring(i, i+1) == ')') {
        depth--;
        if (depth < 0) {
          return false; // More closing than opening parentheses
        }
      }
    }
    
    return depth == 0; // Should be balanced at the end
  }
  
  /**
   * Find the index of the matching closing parenthesis
   * @param str The string to search in
   * @param openPos The position of the opening parenthesis
   * @return Integer The position of the matching closing parenthesis, or -1 if not found
   */
  private static Integer findMatchingClosingParenthesis(String str, Integer openPos) {
    if (openPos >= str.length() || str.substring(openPos, openPos+1) != '(') {
      return -1;
    }
    
    Integer depth = 1;
    
    for (Integer i = openPos + 1; i < str.length(); i++) {
      if (i < str.length() && str.substring(i, i+1) == '(') {
        depth++;
      } else if (i < str.length() && str.substring(i, i+1) == ')') {
        depth--;
        if (depth == 0) {
          return i; // Found the matching closing parenthesis
        }
      }
    }
    
    return -1; // No matching closing parenthesis
  }

  /**
   * Parse a condition string into a Condition object
   * @param conditionString The condition string
   * @return Condition The parsed condition
   */
  private static Condition parseCondition(String conditionString) {
    // Handle parenthesized expressions
    if (conditionString.startsWith('(') && conditionString.endsWith(')')) {
      conditionString = conditionString.substring(1, conditionString.length() - 1).trim();
    }
    
    // List of operators in order of precedence (longer operators first)
    List<String> operators = new List<String>{
      'NOT IN', 'IN', 'LIKE', '!=', '<>', '>=', '<=', '=', '>', '<'
    };

    String operator = null;
    Integer operatorIndex = -1;

    // Find the operator in the condition
    for (String op : operators) {
      Integer index = conditionString.indexOf(' ' + op + ' ');
      if (index != -1) {
        operator = op;
        operatorIndex = index;
        break;
      }
    }

    if (operator == null) {
      throw new SOQLParserException('Invalid condition: ' + conditionString);
    }

    String field = conditionString.substring(0, operatorIndex).trim();
    String value = conditionString.substring(operatorIndex + operator.length() + 2).trim(); // +2 for spaces

    return new Condition(field, operator, value);
  }

  /**
   * Compose a WhereClause object back into a WHERE clause string
   * @param whereClause The WhereClause object to compose
   * @return String The composed WHERE clause string
   */
//  public static String composeWhereClause(WhereClause whereClause) {
//    if (whereClause == null) {
//      return '';
//    }
//
//    String result = composeCondition(whereClause.left);
//
//    if (String.isNotBlank(whereClause.operator) && whereClause.right != null) {
//      result += ' ' + whereClause.operator + ' ' + composeWhereClause(whereClause.right);
//    }
//
//    return result;
//  }

  /**
   * Compose a Condition object into a string
   * @param condition The Condition object to compose
   * @return String The composed condition string
   */
//  private static String composeCondition(Condition condition) {
//    String result = condition.field + ' ' + condition.operator + ' ';
//
//    // Handle different literal types
//    if (condition.literalType == 'STRING' && !condition.value.startsWith('\'') && !condition.value.endsWith('\'')) {
//      result += '\'' + condition.value + '\'';
//    } else {
//      result += condition.value;
//    }
//
//    return result;
//  }

  /**
   * Parse a complete SOQL query and extract just the WHERE clause
   * @param soql The SOQL query string
   * @return WhereClause The parsed WHERE clause
   */
  public static WhereClause extractWhereClause(String soql) {
    if (soql == null || soql.trim() == '') {
      return null;
    }
    
    Integer whereIndex = soql.toUpperCase().indexOf(' WHERE ');
    if (whereIndex == -1) {
      return null;
    }

    String remaining = soql.substring(whereIndex + 7); // 7 is length of " WHERE "

    // Find the next clause after WHERE
    List<String> nextClauses = new List<String>{
      ' GROUP BY ', ' HAVING ', ' ORDER BY ', ' LIMIT ', ' OFFSET '
    };

    Integer nextClauseIndex = -1;
    String nextClause = null;

    for (String clause : nextClauses) {
      Integer index = remaining.toUpperCase().indexOf(clause);
      if (index != -1 && (nextClauseIndex == -1 || index < nextClauseIndex)) {
        nextClauseIndex = index;
        nextClause = clause;
      }
    }

    String whereClauseStr;
    if (nextClauseIndex == -1) {
      whereClauseStr = remaining.trim();
    } else {
      whereClauseStr = remaining.substring(0, nextClauseIndex).trim();
    }

    return parseWhereClause(whereClauseStr);
  }

  /**
   * Custom exception class for SOQL parser errors
   */
  public class SOQLParserException extends Exception {}
}