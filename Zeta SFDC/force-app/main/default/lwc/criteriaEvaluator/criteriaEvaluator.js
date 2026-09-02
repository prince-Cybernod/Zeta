/**
 * Client-side evaluator for the subset of Salesforce Formula syntax used by
 * SObject_Field_Criteria__mdt records driving Application_Question/Section
 * visibility. Lets the LWC re-evaluate visibility without an Apex round trip.
 *
 * Supported grammar:
 *   - Field references: Identifier, Identifier__c, dotted Relationship.Field
 *   - Literals: TRUE / FALSE / NULL (case-insensitive), numbers, "..." or '...' strings
 *   - Comparison: =, ==, !=, <>, <, >, <=, >=
 *   - Logical: AND(...), OR(...), NOT(...), &&, ||, !
 *   - Functions: INCLUDES(field, "literal"), ISBLANK(field), ISPICKVAL(field, "literal"),
 *                CONTAINS(field, "literal"), BEGINS(field, "literal")
 *   - Parentheses for grouping
 *
 * The exported API is intentionally narrow:
 *   evaluateCriteria(formulaExpression, answers, fieldAliasMap?)   -> Boolean
 *   extractReferencedFields(formulaExpression)                     -> string[]
 *
 * `fieldAliasMap` is the only sanctioned extension point for resolving a
 * formula's field-API-name reference against an answers map keyed by something
 * else (e.g., question developer names). It maps fieldApiName -> answersKey.
 * Resist widening the API further; if a future need can be expressed as an
 * alias, prefer that.
 *
 * Unsupported formula features will throw CriteriaEvalError so the caller can
 * fall back to a server round trip if needed.
 */

export class CriteriaEvalError extends Error {
  constructor(message) {
    super(message);
    this.name = 'CriteriaEvalError';
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Evaluate a formula expression against an answers map.
 * @param {string} formulaExpression - the Salesforce-style formula text
 * @param {Object} answers - map of field/question identifiers to current values
 * @param {Map<string,string>} [fieldAliasMap] - optional map of fieldApiName ->
 *   answersKey, consulted as a final fallback when a formula's field reference
 *   doesn't match any direct or strip-`__c`/append-`__c` candidate in `answers`.
 *   Use when the answers map is keyed by something other than the field API
 *   names the formulas reference (e.g., question developer names).
 * @returns {boolean}
 */
export function evaluateCriteria(formulaExpression, answers, fieldAliasMap) {
  if (!formulaExpression || !formulaExpression.trim()) {
    return true;
  }
  const ast = parse(formulaExpression);
  const result = evaluateNode(ast, answers || {}, fieldAliasMap);
  return toBoolean(result);
}

/**
 * Return the set of field API names referenced by a formula expression.
 * @param {string} formulaExpression
 * @returns {string[]}
 */
export function extractReferencedFields(formulaExpression) {
  if (!formulaExpression || !formulaExpression.trim()) {
    return [];
  }
  const ast = parse(formulaExpression);
  const out = new Set();
  collectFields(ast, out);
  return Array.from(out);
}

// ---------------------------------------------------------------------------
// Lexer
// ---------------------------------------------------------------------------

const TOKEN = {
  IDENT: 'IDENT',
  NUMBER: 'NUMBER',
  STRING: 'STRING',
  LPAREN: 'LPAREN',
  RPAREN: 'RPAREN',
  COMMA: 'COMMA',
  DOT: 'DOT',
  OP: 'OP',
  EOF: 'EOF'
};

const TWO_CHAR_OPS = new Set(['==', '!=', '<>', '<=', '>=', '&&', '||']);
const ONE_CHAR_OPS = new Set(['=', '<', '>', '!', '+', '-', '*', '/']);

function tokenize(input) {
  const tokens = [];
  let i = 0;
  while (i < input.length) {
    const ch = input[i];
    if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
      i++;
      continue;
    }
    if (ch === '(') {
      tokens.push({ type: TOKEN.LPAREN });
      i++;
      continue;
    }
    if (ch === ')') {
      tokens.push({ type: TOKEN.RPAREN });
      i++;
      continue;
    }
    if (ch === ',') {
      tokens.push({ type: TOKEN.COMMA });
      i++;
      continue;
    }
    if (ch === '.') {
      tokens.push({ type: TOKEN.DOT });
      i++;
      continue;
    }
    if (ch === '"' || ch === "'") {
      const quote = ch;
      let j = i + 1;
      let value = '';
      while (j < input.length && input[j] !== quote) {
        if (input[j] === '\\' && j + 1 < input.length) {
          value += input[j + 1];
          j += 2;
        } else {
          value += input[j];
          j++;
        }
      }
      if (j >= input.length) {
        throw new CriteriaEvalError(
          `Unterminated string literal starting at index ${i}`
        );
      }
      tokens.push({ type: TOKEN.STRING, value });
      i = j + 1;
      continue;
    }
    if (isDigit(ch) || (ch === '-' && isDigit(input[i + 1] || ''))) {
      // numeric literal — note: '-' as unary is also handled below as OP; keep
      // simple by only consuming leading '-' when followed by a digit.
      let j = i;
      if (input[j] === '-') j++;
      while (j < input.length && (isDigit(input[j]) || input[j] === '.')) j++;
      const raw = input.slice(i, j);
      tokens.push({ type: TOKEN.NUMBER, value: Number(raw) });
      i = j;
      continue;
    }
    if (isIdentStart(ch)) {
      let j = i + 1;
      while (j < input.length && isIdentPart(input[j])) j++;
      tokens.push({ type: TOKEN.IDENT, value: input.slice(i, j) });
      i = j;
      continue;
    }
    const two = input.slice(i, i + 2);
    if (TWO_CHAR_OPS.has(two)) {
      tokens.push({ type: TOKEN.OP, value: two });
      i += 2;
      continue;
    }
    if (ONE_CHAR_OPS.has(ch)) {
      tokens.push({ type: TOKEN.OP, value: ch });
      i++;
      continue;
    }
    throw new CriteriaEvalError(`Unexpected character '${ch}' at index ${i}`);
  }
  tokens.push({ type: TOKEN.EOF });
  return tokens;
}

function isDigit(ch) {
  return ch >= '0' && ch <= '9';
}
function isIdentStart(ch) {
  return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch === '_';
}
function isIdentPart(ch) {
  return isIdentStart(ch) || isDigit(ch);
}

// ---------------------------------------------------------------------------
// Parser (recursive-descent)
// Precedence (lowest -> highest):
//   or  : a || b
//   and : a && b
//   not : ! a
//   cmp : a = b | a != b | a < b | ...
//   primary
// ---------------------------------------------------------------------------

function parse(input) {
  const tokens = tokenize(input);
  const ctx = { tokens, pos: 0 };
  const node = parseOr(ctx);
  if (peek(ctx).type !== TOKEN.EOF) {
    throw new CriteriaEvalError(
      `Unexpected token '${stringifyToken(peek(ctx))}' after expression`
    );
  }
  return node;
}

function peek(ctx) {
  return ctx.tokens[ctx.pos];
}
function consume(ctx) {
  return ctx.tokens[ctx.pos++];
}
function match(ctx, type, value) {
  const t = peek(ctx);
  if (t.type !== type) return false;
  if (value !== undefined && t.value !== value) return false;
  consume(ctx);
  return true;
}
function expect(ctx, type, value) {
  const t = peek(ctx);
  if (t.type !== type || (value !== undefined && t.value !== value)) {
    throw new CriteriaEvalError(
      `Expected ${type}${value !== undefined ? ` '${value}'` : ''} but got '${stringifyToken(t)}'`
    );
  }
  return consume(ctx);
}
function stringifyToken(t) {
  if (!t) return 'EOF';
  if (t.value !== undefined) return String(t.value);
  return t.type;
}

function parseOr(ctx) {
  let left = parseAnd(ctx);
  let t = peek(ctx);
  while (t.type === TOKEN.OP && t.value === '||') {
    consume(ctx);
    const right = parseAnd(ctx);
    left = { kind: 'binary', op: '||', left, right };
    t = peek(ctx);
  }
  return left;
}

function parseAnd(ctx) {
  let left = parseNot(ctx);
  let t = peek(ctx);
  while (t.type === TOKEN.OP && t.value === '&&') {
    consume(ctx);
    const right = parseNot(ctx);
    left = { kind: 'binary', op: '&&', left, right };
    t = peek(ctx);
  }
  return left;
}

function parseNot(ctx) {
  const t = peek(ctx);
  if (t.type === TOKEN.OP && t.value === '!') {
    consume(ctx);
    const operand = parseNot(ctx);
    return { kind: 'unary', op: '!', operand };
  }
  return parseComparison(ctx);
}

function parseComparison(ctx) {
  const left = parsePrimary(ctx);
  const t = peek(ctx);
  if (
    t.type === TOKEN.OP &&
    (t.value === '=' ||
      t.value === '==' ||
      t.value === '!=' ||
      t.value === '<>' ||
      t.value === '<' ||
      t.value === '>' ||
      t.value === '<=' ||
      t.value === '>=')
  ) {
    consume(ctx);
    const right = parsePrimary(ctx);
    return { kind: 'comparison', op: t.value, left, right };
  }
  return left;
}

function parsePrimary(ctx) {
  const t = peek(ctx);
  if (t.type === TOKEN.LPAREN) {
    consume(ctx);
    const expr = parseOr(ctx);
    expect(ctx, TOKEN.RPAREN);
    return expr;
  }
  if (t.type === TOKEN.NUMBER) {
    consume(ctx);
    return { kind: 'literal', value: t.value };
  }
  if (t.type === TOKEN.STRING) {
    consume(ctx);
    return { kind: 'literal', value: t.value };
  }
  if (t.type === TOKEN.IDENT) {
    consume(ctx);
    const upper = t.value.toUpperCase();
    // Reserved literals
    if (upper === 'TRUE') return { kind: 'literal', value: true };
    if (upper === 'FALSE') return { kind: 'literal', value: false };
    if (upper === 'NULL') return { kind: 'literal', value: null };

    // Function call?
    if (peek(ctx).type === TOKEN.LPAREN) {
      consume(ctx); // LPAREN
      const args = [];
      if (peek(ctx).type !== TOKEN.RPAREN) {
        args.push(parseOr(ctx));
        while (match(ctx, TOKEN.COMMA)) {
          args.push(parseOr(ctx));
        }
      }
      expect(ctx, TOKEN.RPAREN);
      return { kind: 'call', name: upper, args };
    }

    // Field reference (may include dot-paths)
    const parts = [t.value];
    while (peek(ctx).type === TOKEN.DOT) {
      consume(ctx); // DOT
      const next = expect(ctx, TOKEN.IDENT);
      parts.push(next.value);
    }
    return { kind: 'field', name: parts.join('.'), path: parts };
  }
  throw new CriteriaEvalError(`Unexpected token '${stringifyToken(t)}'`);
}

// ---------------------------------------------------------------------------
// Evaluator
// ---------------------------------------------------------------------------

function evaluateNode(node, answers, fieldAliasMap) {
  switch (node.kind) {
    case 'literal':
      return node.value;
    case 'field':
      return resolveField(node, answers, fieldAliasMap);
    case 'unary':
      if (node.op === '!')
        return !toBoolean(evaluateNode(node.operand, answers, fieldAliasMap));
      throw new CriteriaEvalError(`Unsupported unary operator: ${node.op}`);
    case 'binary':
      if (node.op === '&&') {
        const l = toBoolean(evaluateNode(node.left, answers, fieldAliasMap));
        if (!l) return false;
        return toBoolean(evaluateNode(node.right, answers, fieldAliasMap));
      }
      if (node.op === '||') {
        const l = toBoolean(evaluateNode(node.left, answers, fieldAliasMap));
        if (l) return true;
        return toBoolean(evaluateNode(node.right, answers, fieldAliasMap));
      }
      throw new CriteriaEvalError(`Unsupported binary operator: ${node.op}`);
    case 'comparison':
      return evaluateComparison(node, answers, fieldAliasMap);
    case 'call':
      return evaluateCall(node, answers, fieldAliasMap);
    default:
      throw new CriteriaEvalError(`Unknown node kind: ${node.kind}`);
  }
}

function evaluateComparison(node, answers, fieldAliasMap) {
  const left = evaluateNode(node.left, answers, fieldAliasMap);
  const right = evaluateNode(node.right, answers, fieldAliasMap);

  switch (node.op) {
    case '=':
    case '==':
      return looseEquals(left, right);
    case '!=':
    case '<>':
      return !looseEquals(left, right);
    case '<':
      return compareOrdered(left, right) < 0;
    case '>':
      return compareOrdered(left, right) > 0;
    case '<=':
      return compareOrdered(left, right) <= 0;
    case '>=':
      return compareOrdered(left, right) >= 0;
    default:
      throw new CriteriaEvalError(
        `Unsupported comparison operator: ${node.op}`
      );
  }
}

function evaluateCall(node, answers, fieldAliasMap) {
  switch (node.name) {
    case 'AND': {
      for (const arg of node.args) {
        if (!toBoolean(evaluateNode(arg, answers, fieldAliasMap))) return false;
      }
      return true;
    }
    case 'OR': {
      for (const arg of node.args) {
        if (toBoolean(evaluateNode(arg, answers, fieldAliasMap))) return true;
      }
      return false;
    }
    case 'NOT': {
      requireArity(node, 1);
      return !toBoolean(evaluateNode(node.args[0], answers, fieldAliasMap));
    }
    case 'INCLUDES': {
      // INCLUDES(multipicklistField, "literal") — true if literal appears in the
      // semicolon-delimited multipicklist value.
      requireArity(node, 2);
      const field = evaluateNode(node.args[0], answers, fieldAliasMap);
      const literal = evaluateNode(node.args[1], answers, fieldAliasMap);
      return includesMultipicklist(field, literal);
    }
    case 'ISPICKVAL': {
      // ISPICKVAL(picklistField, "literal") — true if the field equals literal.
      requireArity(node, 2);
      const field = evaluateNode(node.args[0], answers, fieldAliasMap);
      const literal = evaluateNode(node.args[1], answers, fieldAliasMap);
      return looseEquals(field, literal);
    }
    case 'ISBLANK':
    case 'ISNULL': {
      requireArity(node, 1);
      const v = evaluateNode(node.args[0], answers, fieldAliasMap);
      return isBlankValue(v);
    }
    case 'NOT_BLANK':
    case 'NOTISBLANK': {
      requireArity(node, 1);
      return !isBlankValue(evaluateNode(node.args[0], answers, fieldAliasMap));
    }
    case 'CONTAINS': {
      requireArity(node, 2);
      const haystack = evaluateNode(node.args[0], answers, fieldAliasMap);
      const needle = evaluateNode(node.args[1], answers, fieldAliasMap);
      if (haystack == null || needle == null) return false;
      return String(haystack).indexOf(String(needle)) !== -1;
    }
    case 'BEGINS': {
      requireArity(node, 2);
      const haystack = evaluateNode(node.args[0], answers, fieldAliasMap);
      const needle = evaluateNode(node.args[1], answers, fieldAliasMap);
      if (haystack == null || needle == null) return false;
      return String(haystack).startsWith(String(needle));
    }
    case 'TRUE':
      return true;
    case 'FALSE':
      return false;
    default:
      throw new CriteriaEvalError(`Unsupported function: ${node.name}`);
  }
}

function requireArity(node, expected) {
  if (node.args.length !== expected) {
    throw new CriteriaEvalError(
      `Function ${node.name} expects ${expected} argument(s) but got ${node.args.length}`
    );
  }
}

// ---------------------------------------------------------------------------
// Value helpers
// ---------------------------------------------------------------------------

/**
 * Resolve a field reference against the answers map. Tries a sequence of
 * lookups so the caller can pass either field API names, question developer
 * names, or both — whichever matches first wins. If still nothing matches and
 * a `fieldAliasMap` is provided, each candidate is checked against the alias
 * map and the mapped key is looked up in `answers` as a final fallback.
 */
function resolveField(node, answers, fieldAliasMap) {
  const path = node.path;
  if (!path || path.length === 0) return undefined;

  // Direct hits on the joined name and the leaf segment.
  const candidates = [node.name, path[path.length - 1]];

  // Strip a trailing __c so a question keyed by developer name (without __c)
  // still matches a formula referencing the field API name.
  for (const candidate of [...candidates]) {
    if (candidate.endsWith('__c')) {
      candidates.push(candidate.slice(0, -3));
    } else {
      candidates.push(`${candidate}__c`);
    }
  }

  for (const key of candidates) {
    if (key in answers) {
      return answers[key];
    }
  }

  // Alias-map fallback: the formula references a field API name whose answer
  // is keyed by something else entirely (e.g., a question developer name that
  // differs from the field API name by more than `__c`).
  if (fieldAliasMap) {
    for (const candidate of candidates) {
      if (fieldAliasMap.has(candidate)) {
        const aliasKey = fieldAliasMap.get(candidate);
        if (aliasKey in answers) {
          return answers[aliasKey];
        }
      }
    }
  }
  return undefined;
}

function collectFields(node, out) {
  if (!node) return;
  switch (node.kind) {
    case 'field':
      out.add(node.name);
      // Also surface the leaf for callers building field->question maps.
      if (node.path && node.path.length > 1) {
        out.add(node.path[node.path.length - 1]);
      }
      break;
    case 'unary':
      collectFields(node.operand, out);
      break;
    case 'binary':
    case 'comparison':
      collectFields(node.left, out);
      collectFields(node.right, out);
      break;
    case 'call':
      for (const arg of node.args) collectFields(arg, out);
      break;
    case 'literal':
    default:
      break;
  }
}

function toBoolean(value) {
  if (value === true || value === false) return value;
  if (value == null) return false;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const lower = value.trim().toLowerCase();
    if (lower === 'true') return true;
    if (lower === 'false' || lower === '') return false;
    return true;
  }
  return Boolean(value);
}

function looseEquals(left, right) {
  // Treat null and undefined as equal to one another; otherwise allow string
  // <-> boolean comparisons since multipicklists arrive as strings.
  if (left == null && right == null) return true;
  if (left == null || right == null) return false;
  if (typeof left === 'boolean' || typeof right === 'boolean') {
    return toBoolean(left) === toBoolean(right);
  }
  if (typeof left === 'number' && typeof right === 'number') {
    return left === right;
  }
  return String(left) === String(right);
}

function compareOrdered(left, right) {
  if (left == null || right == null) return NaN;
  if (typeof left === 'number' && typeof right === 'number') {
    return left - right;
  }
  const a = String(left);
  const b = String(right);
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

function includesMultipicklist(fieldValue, literal) {
  if (fieldValue == null) return false;
  const lit = String(literal);
  if (Array.isArray(fieldValue)) {
    return fieldValue.some((v) => String(v) === lit);
  }
  const parts = String(fieldValue).split(';');
  return parts.some((p) => p === lit);
}

function isBlankValue(value) {
  if (value == null) return true;
  if (typeof value === 'string') return value.trim() === '';
  return false;
}