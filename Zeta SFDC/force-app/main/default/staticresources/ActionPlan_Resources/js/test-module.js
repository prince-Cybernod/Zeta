// Test script for soql-module.js
// This file demonstrates how to import and use the SOQL parser as an ES module

// Import specific functions from the module
import { parse, debug, extractFieldsFromWhereClause } from './soql-module.js';

// Test parsing a simple SOQL query
function testParse() {
  console.log('Testing parse function...');
  
  const query = 'SELECT Id, Name FROM Account WHERE Name = \'Test\' AND Rating = \'Hot\'';
  
  try {
    const result = parse(query);
    console.log('Parse result:', result);
    
    if (result && result.where) {
      console.log('WHERE clause parsed successfully');
      return true;
    } else {
      console.error('Failed to parse WHERE clause');
      return false;
    }
  } catch (error) {
    console.error('Error parsing query:', error);
    return false;
  }
}

// Test extracting fields from a WHERE clause
function testExtractFields() {
  console.log('Testing extractFieldsFromWhereClause function...');
  
  const query = 'SELECT Id FROM Account WHERE Name = \'Test\' AND Rating = \'Hot\'';
  
  try {
    const result = parse(query);
    
    if (result && result.where) {
      const fields = extractFieldsFromWhereClause(result.where);
      console.log('Extracted fields:', fields);
      
      if (fields.includes('Name') && fields.includes('Rating')) {
        console.log('Field extraction successful');
        return true;
      } else {
        console.error('Failed to extract expected fields');
        return false;
      }
    } else {
      console.error('Failed to parse WHERE clause');
      return false;
    }
  } catch (error) {
    console.error('Error extracting fields:', error);
    return false;
  }
}

// Run the tests
console.log('Running SOQL module tests...');
const parseSuccess = testParse();
const extractSuccess = testExtractFields();

if (parseSuccess && extractSuccess) {
  console.log('All tests passed!');
} else {
  console.error('Some tests failed');
}

// Example of how to use the module in a real application
export function greet(name) {
  console.log(`Hello, ${name}! Welcome to the SOQL parser module.`);
  
  // Example of parsing a query with the person's name
  const query = `SELECT Id FROM Contact WHERE Name = '${name}'`;
  const result = parse(query);
  
  console.log(`I've parsed a query for you: ${query}`);
  console.log('Parse result:', result);
  
  return `Greeting completed for ${name}`;
}
