// ES Module wrapper for soql-parser-mjs.js
// This file provides a clean ES module interface to the SOQL parser functionality

// Import the parseQuery function from soql-parser-mjs.js
// Note: In a real implementation, this would use a relative path import
// but since we're loading this via Visualforce, we'll rely on the global parseQuery function
// that's made available when soql-parser-mjs.js is loaded

/**
 * Parse a SOQL query string into a structured object
 * @param {string} query - The SOQL query to parse
 * @returns {Object} The parsed query structure
 */
export function parse(query) {
  try {
    // Use the global parseQuery function from soql-parser-mjs.js
    return parseQuery(query);
  } catch (e) {
    console.error('Error parsing SOQL query:', e);
    return { error: e.message };
  }
}

/**
 * Debug version of parse that logs additional information
 * @param {string} query - The SOQL query to parse
 * @returns {Object} The parsed query structure
 */
export function debug(query) {
  try {
    console.log('SOQL Debug: Parsing query', query);
    const result = parseQuery(query);
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
  } catch (e) {
    console.error('SOQL Debug: Error parsing query', e);
    return { error: e.message };
  }
}

/**
 * Helper function to extract fields from a WHERE clause
 * @param {Object} whereClause - The WHERE clause object from the parsed query
 * @param {Array} [fields=[]] - Array to collect the extracted field names
 * @returns {Array} Array of field names
 */
export function extractFieldsFromWhereClause(whereClause, fields = []) {
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

/**
 * Convert field names from relationship notation to SObject notation
 * @param {string} fieldName - The field name to convert
 * @returns {string} The converted field name
 */
export function convertFieldNotation(fieldName) {
  if (!fieldName) return '';
  
  // Clean the field name (remove parentheses)
  let cleanedField = fieldName.trim();
  while (cleanedField.startsWith('(')) {
    cleanedField = cleanedField.substring(1).trim();
  }
  while (cleanedField.endsWith(')')) {
    cleanedField = cleanedField.substring(0, cleanedField.length - 1).trim();
  }
  
  // Convert relationship notation to SObject notation
  if (cleanedField.includes('__r.')) {
    return cleanedField.replace('__r.', '__c.');
  }
  
  return cleanedField;
}

// Export utility functions for checking types
export const utils = {
  isSubquery: function(query) {
    return typeof query.relationshipName === 'string';
  },
  isFieldSubquery: function(value) {
    return !!value && !!value.type && value.type === "FieldSubquery";
  },
  isWhereClauseWithRightCondition: function(value) {
    return !!value && !!value.operator && !!value.right;
  },
  hasAlias: function(value) {
    return value && value.alias !== undefined && value.alias !== null;
  }
};
