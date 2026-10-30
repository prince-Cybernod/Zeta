// Create a global soql object for browser usage
(function(global) {
    // Include the CommonJS version of the parser
    // This will be executed in the current scope, not global
    
    // src/utils.ts
    function isToken(val) {
      val = Array.isArray(val) ? val[0] : val;
      return val.image && true;
    }
    function isSubqueryFromFlag(val, isSubquery2) {
      return isSubquery2;
    }
    function isString(val) {
      return typeof val === "string";
    }
    function isStringArray(val) {
      if (!val) {
        return false;
      }
      return val.every((item) => isString(item));
    }
    function isNumber(val) {
      return Number.isFinite(val);
    }
    function isNil(val) {
      return val === null || val === void 0;
    }
    function get(val, suffix, prefix) {
      return isNil(val) ? "" : `${prefix || ""}${val}${suffix || ""}`;
    }
    function getAsArrayStr(val, alwaysParens = false) {
      if (Array.isArray(val)) {
        if (val.length > 0) {
          return `(${val.join(", ")})`;
        } else {
          return alwaysParens ? "()" : "";
        }
      } else {
        return alwaysParens ? `(${val || ""})` : val || "";
      }
    }
    function generateParens(count, character, joinCharacter = "") {
      return isNumber(count) && count > 0 ? new Array(count).fill(character).join(joinCharacter) : "";
    }
    function getParams(functionFieldExp) {
      if (!functionFieldExp.parameters || functionFieldExp.parameters.length === 0) {
        return [];
      }
      if (isStringArray(functionFieldExp.parameters)) {
        return functionFieldExp.parameters;
      }
      if (isString(functionFieldExp.parameters[0])) {
        return [functionFieldExp.parameters[0]];
      }
      return getParams(functionFieldExp.parameters[0]);
    }
    function isNestedParamAggregateFunction(functionFieldExp) {
      if (!functionFieldExp.parameters || functionFieldExp.parameters.length === 0) {
        return false;
      }
      const parameter = functionFieldExp.parameters[0];
      if (isString(parameter)) {
        return false;
      }
      return !!parameter.isAggregateFn;
    }
    function hasAlias(value) {
      return value && !isNil(value.alias);
    }
    function isComposeField(input) {
      return isString(input.field) && !Array.isArray(input.relationships) && !Array.isArray(input.conditions);
    }
    function isComposeFieldFunction(input) {
      return !isNil(input.functionName || input.fn);
    }
    function isComposeFieldRelationship(input) {
      return isString(input.field) && Array.isArray(input.relationships);
    }
    function isComposeFieldSubquery(input) {
      return !isNil(input.subquery);
    }
    function isComposeFieldTypeof(input) {
      return isString(input.field) && Array.isArray(input.conditions);
    }
    function isSubquery(query) {
      return isString(query.relationshipName);
    }
    function isFieldSubquery(value) {
      return !!value && !!value.type && value.type === "FieldSubquery";
    }
    function isWhereClauseWithRightCondition(value) {
      return !!value && !!value.operator && !!value.right;
    }
    function isHavingClauseWithRightCondition(value) {
      return !!value && !!value.operator && !!value.right;
    }
    function isWhereOrHavingClauseWithRightCondition(value) {
      return !!value && !!value.operator && !!value.right;
    }
    function isValueCondition(value) {
      return value && isString(value.field) && isString(value.operator) && !isNil(value.value);
    }
    function isValueWithDateLiteralCondition(value) {
      return value && isString(value.field) && isString(value.operator) && !isNil(value.value) && (value.literalType === "DATE_LITERAL" || Array.isArray(value.literalType) && value.literalType[0] === "DATE_LITERAL");
    }
    function isValueWithDateNLiteralCondition(value) {
      return value && isString(value.field) && isString(value.operator) && !isNil(value.value) && !isNil(value.dateLiteralVariable);
    }
    function isValueFunctionCondition(value) {
      return value && !isNil(value.fn) && isString(value.operator) && !isNil(value.value);
    }
    function isNegationCondition(value) {
      return value && isNumber(value.openParen) && isNil(value.operator) && isNil(value.field) && isNil(value.fn) && isNil(value.closeParen);
    }
    function isValueQueryCondition(value) {
      return value && isString(value.field) && isString(value.operator) && !isNil(value.valueQuery) && isNil(value.value);
    }
    function isOrderByField(value) {
      return value && !isNil(value.field);
    }
    function isOrderByFn(value) {
      return value && !isNil(value.fn);
    }
    function isGroupByField(value) {
      return value && !isNil(value.field);
    }
    function isGroupByFn(value) {
      return value && !isNil(value.fn);
    }
    function isInOperator(operator) {
      return ["IN", "NOT IN", "INCLUDES", "EXCLUDES"].includes(operator);
    }
    function getWhereValue(value, literalType, operator) {
      if (isNil(literalType)) {
        return value;
      }
      if (operator && literalType !== "APEX_BIND_VARIABLE" && isInOperator(operator) && !Array.isArray(value) && (value = [value], literalType = Array.isArray(literalType) ? literalType : [literalType]), Array.isArray(literalType) && Array.isArray(value)) {
        return value.map((val, i) => getWhereValueLiteral(val, literalType?.[i]));
      }
      switch (Array.isArray(literalType) && (literalType = literalType[0]), literalType) {
        case "STRING":
          return Array.isArray(value) ? value.filter(Boolean).map((val) => isString(val) && val.startsWith("'") ? val : `'${val ?? ""}'`) : (value = String(value ?? ""), isString(value) && value.startsWith("'") ? value : `'${value ?? ""}'`);
        case "APEX_BIND_VARIABLE":
          return `:${value}`;
        default:
          return value;
      }
    }
    function getWhereValueLiteral(value, literalType) {
      switch (literalType) {
        case "STRING":
          return isString(value) && value.startsWith("'") ? value : `'${value ?? ""}'`;
        default:
          return value;
      }
    }

    // Import the parser code
    // This is a more complete implementation of the parser
    function parseQuery(soql, options) {
      // Basic WHERE clause parsing for SOQL
      // This is a simplified version that focuses on extracting field names from WHERE clauses
      
      try {
        // If soql is not a string, return an empty object
        if (typeof soql !== 'string') {
          console.error('SOQL query must be a string');
          return { fields: [], sObject: "", where: null };
        }
        
        // Extract the WHERE clause
        let whereClause = null;
        const whereIndex = soql.toUpperCase().indexOf(' WHERE ');
        
        if (whereIndex !== -1) {
          // Extract everything after WHERE
          let remaining = soql.substring(whereIndex + 7); // 7 is length of " WHERE "
          
          // Find the next clause after WHERE
          const nextClauses = [' GROUP BY ', ' HAVING ', ' ORDER BY ', ' LIMIT ', ' OFFSET '];
          let nextClauseIndex = -1;
          
          for (const clause of nextClauses) {
            const index = remaining.toUpperCase().indexOf(clause);
            if (index !== -1 && (nextClauseIndex === -1 || index < nextClauseIndex)) {
              nextClauseIndex = index;
            }
          }
          
          // Extract the WHERE clause
          const whereClauseStr = nextClauseIndex === -1 ? 
            remaining.trim() : 
            remaining.substring(0, nextClauseIndex).trim();
          
          // Parse the WHERE clause
          whereClause = parseWhereClause(whereClauseStr);
        }
        
        // Return a basic structure with the WHERE clause
        return {
          fields: [],
          sObject: "",
          where: whereClause
        };
      } catch (error) {
        console.error('Error parsing SOQL query:', error);
        return { fields: [], sObject: "", where: null };
      }
    }
    
    // Parse a WHERE clause string into a structured object
    function parseWhereClause(whereString) {
      if (!whereString) return null;
      
      // Handle parenthesized expressions
      if (whereString.startsWith('(') && isBalancedParentheses(whereString)) {
        // Check if the entire string is wrapped in parentheses
        if (findMatchingClosingParenthesis(whereString, 0) === whereString.length - 1) {
          // Remove the outer parentheses and parse the content
          return parseWhereClause(whereString.substring(1, whereString.length - 1).trim());
        }
      }
      
      // Find the top-level logical operator (AND/OR)
      const andIndex = findTopLevelOperator(whereString, ' AND ');
      if (andIndex !== -1) {
        const leftPart = whereString.substring(0, andIndex).trim();
        const rightPart = whereString.substring(andIndex + 5).trim(); // 5 is length of " AND "
        
        const leftClause = parseWhereClause(leftPart);
        const rightClause = parseWhereClause(rightPart);
        
        return {
          left: leftClause.left,
          operator: 'AND',
          right: rightClause
        };
      }
      
      const orIndex = findTopLevelOperator(whereString, ' OR ');
      if (orIndex !== -1) {
        const leftPart = whereString.substring(0, orIndex).trim();
        const rightPart = whereString.substring(orIndex + 4).trim(); // 4 is length of " OR "
        
        const leftClause = parseWhereClause(leftPart);
        const rightClause = parseWhereClause(rightPart);
        
        return {
          left: leftClause.left,
          operator: 'OR',
          right: rightClause
        };
      }
      
      // If no logical operators found, it's a simple condition
      return {
        left: parseCondition(whereString)
      };
    }
    
    // Parse a condition string into a structured object
    function parseCondition(conditionString) {
      // Handle parenthesized expressions
      if (conditionString.startsWith('(') && conditionString.endsWith(')')) {
        conditionString = conditionString.substring(1, conditionString.length - 1).trim();
      }
      
      // List of operators in order of precedence (longer operators first)
      const operators = [
        'NOT IN', 'IN', 'LIKE', '!=', '<>', '>=', '<=', '=', '>', '<'
      ];
      
      let operator = null;
      let operatorIndex = -1;
      
      // Find the operator in the condition
      for (const op of operators) {
        const index = conditionString.indexOf(' ' + op + ' ');
        if (index !== -1) {
          operator = op;
          operatorIndex = index;
          break;
        }
      }
      
      if (operator === null) {
        console.error('Invalid condition: ' + conditionString);
        return { field: conditionString, operator: '=', value: null };
      }
      
      const field = conditionString.substring(0, operatorIndex).trim();
      const value = conditionString.substring(operatorIndex + operator.length + 2).trim(); // +2 for spaces
      
      return { field, operator, value };
    }
    
    // Helper function to find a top-level operator in a string, respecting parentheses
    function findTopLevelOperator(str, operator) {
      let depth = 0;
      
      // Start from the beginning to prioritize left-to-right evaluation
      for (let i = 0; i <= str.length - operator.length; i++) {
        if (str[i] === '(') {
          depth++;
        } else if (str[i] === ')') {
          depth--;
        } else if (depth === 0 && i + operator.length <= str.length) {
          // Check if we found the operator at the current position
          if (str.substring(i, i + operator.length) === operator) {
            return i;
          }
        }
      }
      
      return -1;
    }
    
    // Helper function to check if a string has balanced parentheses
    function isBalancedParentheses(str) {
      let depth = 0;
      
      for (let i = 0; i < str.length; i++) {
        if (str[i] === '(') {
          depth++;
        } else if (str[i] === ')') {
          depth--;
          if (depth < 0) {
            return false; // More closing than opening parentheses
          }
        }
      }
      
      return depth === 0; // Should be balanced at the end
    }
    
    // Helper function to find the matching closing parenthesis
    function findMatchingClosingParenthesis(str, openPos) {
      if (openPos >= str.length || str[openPos] !== '(') {
        return -1;
      }
      
      let depth = 1;
      
      for (let i = openPos + 1; i < str.length; i++) {
        if (str[i] === '(') {
          depth++;
        } else if (str[i] === ')') {
          depth--;
          if (depth === 0) {
            return i; // Found the matching closing parenthesis
          }
        }
      }
      
      return -1; // No matching closing parenthesis
    }

    // Create the global soql object with the necessary methods
    global.soql = {
      parse: parseQuery,
      // Add other methods as needed
      isSubquery: isSubquery,
      isFieldSubquery: isFieldSubquery,
      isWhereClauseWithRightCondition: isWhereClauseWithRightCondition,
      isHavingClauseWithRightCondition: isHavingClauseWithRightCondition,
      isWhereOrHavingClauseWithRightCondition: isWhereOrHavingClauseWithRightCondition,
      isValueCondition: isValueCondition,
      isValueWithDateLiteralCondition: isValueWithDateLiteralCondition,
      isValueWithDateNLiteralCondition: isValueWithDateNLiteralCondition,
      isValueFunctionCondition: isValueFunctionCondition,
      isNegationCondition: isNegationCondition,
      isValueQueryCondition: isValueQueryCondition,
      isOrderByField: isOrderByField,
      isOrderByFn: isOrderByFn,
      isGroupByField: isGroupByField,
      isGroupByFn: isGroupByFn,
      hasAlias: hasAlias
    };
})(typeof window !== 'undefined' ? window : this);

// Log a message to confirm the soql object is available
console.log('soql-parser-browser.js loaded, soql object is available');

// Add a debug function to the soql object for troubleshooting
global.soql.debug = function(query) {
  try {
    console.log('SOQL Debug: Parsing query', query);
    
    // Parse the query
    const result = this.parse(query);
    
    // Log the result
    console.log('SOQL Debug: Parse result', result);
    
    // If there's a WHERE clause, log its structure
    if (result.where) {
      console.log('SOQL Debug: WHERE clause structure', result.where);
      
      // Extract and log the fields from the WHERE clause
      const fields = extractFieldsFromWhereClause(result.where);
      console.log('SOQL Debug: Extracted fields', fields);
    } else {
      console.log('SOQL Debug: No WHERE clause found');
    }
    
    return result;
  } catch (error) {
    console.error('SOQL Debug: Error parsing query', error);
    return { fields: [], sObject: "", where: null, error: error.message };
  }
};

// Helper function to extract fields from a WHERE clause
function extractFieldsFromWhereClause(whereClause, fields = []) {
  if (!whereClause) return fields;
  
  // Handle conditions
  if (whereClause.left && whereClause.left.field) {
    fields.push(whereClause.left.field);
  }
  
  // Handle nested conditions
  if (whereClause.right) {
    extractFieldsFromWhereClause(whereClause.right, fields);
  }
  
  return fields;
}
