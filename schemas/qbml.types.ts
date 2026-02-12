/**
 * QBML TypeScript Type Definitions
 *
 * These types provide compile-time type safety for QBML query definitions.
 * Use with TypeScript for better developer experience and error prevention.
 *
 * Usage:
 *   import type { QBMLQuery, QBMLAction } from './qbml.types';
 *
 *   const query: QBMLQuery = [
 *     { from: "users" },
 *     { select: ["id", "name"] },
 *     { get: true }
 *   ];
 */

// =============================================================================
// CORE TYPES
// =============================================================================

/** A complete QBML query definition */
export type QBMLQuery = QBMLAction[];

/** Any valid QBML action */
export type QBMLAction =
  | SourceAction
  | SelectAction
  | WhereAction
  | JoinAction
  | GroupAction
  | OrderAction
  | LimitAction
  | LockAction
  | CTEAction
  | UnionAction
  | ExecutorAction;

// =============================================================================
// VALUE TYPES
// =============================================================================

/** Reference to a runtime parameter */
export interface ParamRef {
  $param: string;
}

/** Raw SQL expression (inline) */
export interface RawExpression {
  $raw: string | { sql: string; bindings?: unknown[] };
}

/** Any value that can be used in conditions */
export type AnyValue =
  | string
  | number
  | boolean
  | null
  | unknown[]
  | ParamRef
  | RawExpression;

/** SQL comparison operators */
export type Operator =
  | '='
  | '<>'
  | '!='
  | '<'
  | '>'
  | '<='
  | '>='
  | 'like'
  | 'not like'
  | 'ilike'
  | 'between'
  | 'in'
  | 'not in'
  | 'is'
  | 'is not';

/** Sort direction */
export type SortDirection = 'asc' | 'desc' | 'ASC' | 'DESC';

// =============================================================================
// SOURCE ACTIONS
// =============================================================================

export type SourceAction =
  | FromAction
  | TableAction
  | FromSubAction
  | FromRawAction;

export interface FromAction {
  from: string | { table?: string; name?: string };
}

export interface TableAction {
  table: string;
}

export interface FromSubAction {
  fromSub: string | { alias: string };
  query: QBMLQuery;
  alias?: string;
}

export interface FromRawAction {
  fromRaw: string;
}

// =============================================================================
// SELECT ACTIONS
// =============================================================================

export type SelectAction =
  | SelectColumnsAction
  | AddSelectAction
  | DistinctAction
  | SelectRawAction
  | SubSelectAction
  | SelectAggregateAction;

export interface SelectColumnsAction {
  select:
    | string
    | (string | RawExpression)[]
    | { columns?: string | string[]; column?: string };
}

export interface AddSelectAction {
  addSelect: string | (string | RawExpression)[];
}

export interface DistinctAction {
  distinct: true;
}

export interface SelectRawAction {
  selectRaw: string | [string, unknown[]?];
}

export interface SubSelectAction {
  subSelect: string | { alias: string };
  query: QBMLQuery;
  alias?: string;
}

export interface SelectAggregateAction {
  selectCount?: string | [string, string];
  selectSum?: string | [string, string];
  selectAvg?: string | [string, string];
  selectMin?: string | [string, string];
  selectMax?: string | [string, string];
}

// =============================================================================
// WHERE ACTIONS
// =============================================================================

export type WhereAction =
  | WhereBasicAction
  | WhereInAction
  | WhereBetweenAction
  | WhereLikeAction
  | WhereNullAction
  | WhereColumnAction
  | WhereExistsAction
  | WhereRawAction;

/** Base interface for conditional actions */
export interface ConditionalAction {
  when?: WhenCondition;
  else?: QBMLAction | QBMLAction[];
}

export interface WhereBasicAction extends ConditionalAction {
  where?: WhereClauseValue;
  andWhere?: WhereClauseValue;
  orWhere?: WhereClauseValue;
}

export type WhereClauseValue =
  | [string, AnyValue]
  | [string, string, AnyValue]
  | WhereAction[] // Nested WHERE
  | { column: string; operator?: Operator; value: AnyValue };

export interface WhereInAction extends ConditionalAction {
  whereIn?: WhereInValue;
  whereNotIn?: WhereInValue;
  andWhereIn?: WhereInValue;
  andWhereNotIn?: WhereInValue;
  orWhereIn?: WhereInValue;
  orWhereNotIn?: WhereInValue;
}

export type WhereInValue =
  | [string, unknown[] | ParamRef | RawExpression]
  | { column: string; values: unknown[] | ParamRef | RawExpression };

export interface WhereBetweenAction extends ConditionalAction {
  whereBetween?: WhereBetweenValue;
  whereNotBetween?: WhereBetweenValue;
  andWhereBetween?: WhereBetweenValue;
  andWhereNotBetween?: WhereBetweenValue;
  orWhereBetween?: WhereBetweenValue;
  orWhereNotBetween?: WhereBetweenValue;
}

export type WhereBetweenValue =
  | [string, AnyValue, AnyValue]
  | { column: string; start: AnyValue; end: AnyValue };

export interface WhereLikeAction extends ConditionalAction {
  whereLike?: WhereLikeValue;
  whereNotLike?: WhereLikeValue;
  andWhereLike?: WhereLikeValue;
  andWhereNotLike?: WhereLikeValue;
  orWhereLike?: WhereLikeValue;
  orWhereNotLike?: WhereLikeValue;
}

export type WhereLikeValue =
  | [string, AnyValue]
  | { column: string; value: AnyValue };

export interface WhereNullAction extends ConditionalAction {
  whereNull?: string | { column: string };
  whereNotNull?: string | { column: string };
  andWhereNull?: string | { column: string };
  andWhereNotNull?: string | { column: string };
  orWhereNull?: string | { column: string };
  orWhereNotNull?: string | { column: string };
}

export interface WhereColumnAction extends ConditionalAction {
  whereColumn?: WhereColumnValue;
  andWhereColumn?: WhereColumnValue;
  orWhereColumn?: WhereColumnValue;
}

export type WhereColumnValue =
  | [string, string]
  | [string, string, string]
  | { first: string; operator?: Operator; second: string };

export interface WhereExistsAction extends ConditionalAction {
  whereExists?: true;
  whereNotExists?: true;
  andWhereExists?: true;
  andWhereNotExists?: true;
  orWhereExists?: true;
  orWhereNotExists?: true;
  query: QBMLQuery;
}

export interface WhereRawAction extends ConditionalAction {
  whereRaw?: RawValue;
  andWhereRaw?: RawValue;
  orWhereRaw?: RawValue;
}

export type RawValue =
  | string
  | [string, unknown[]?]
  | { sql: string; bindings?: unknown[] };

// =============================================================================
// JOIN ACTIONS
// =============================================================================

export type JoinAction =
  | SimpleJoinAction
  | JoinSubAction
  | JoinRawAction
  | CrossJoinAction;

export interface SimpleJoinAction {
  join?: JoinValue;
  innerJoin?: JoinValue;
  leftJoin?: JoinValue;
  rightJoin?: JoinValue;
  leftOuterJoin?: JoinValue;
  rightOuterJoin?: JoinValue;
  on?: OnClause[];
}

export type JoinValue =
  | string
  | [string, string, string]
  | [string, string, string, string]
  | { table: string; first?: string; operator?: Operator; second?: string };

export interface OnClause {
  on?: [string, string, string];
  andOn?: [string, string, string];
  orOn?: [string, string, string];
}

export interface JoinSubAction {
  joinSub?: string;
  leftJoinSub?: string;
  rightJoinSub?: string;
  query: QBMLQuery;
  on?: OnClause[];
  alias?: string;
}

export interface JoinRawAction {
  joinRaw?: string[];
  leftJoinRaw?: string[];
  rightJoinRaw?: string[];
}

export interface CrossJoinAction {
  crossJoin: string;
}

// =============================================================================
// GROUP/HAVING ACTIONS
// =============================================================================

export type GroupAction = GroupByAction | HavingAction;

export interface GroupByAction {
  groupBy:
    | string
    | string[]
    | { columns?: string | string[]; column?: string };
}

export interface HavingAction {
  having?: HavingValue;
  andHaving?: HavingValue;
  orHaving?: HavingValue;
  havingRaw?: RawValue;
}

export type HavingValue =
  | [string, string, AnyValue]
  | { column: string; operator?: Operator; value: AnyValue };

// =============================================================================
// ORDER ACTIONS
// =============================================================================

export type OrderAction =
  | OrderByAction
  | OrderByDirectionAction
  | OrderByRawAction
  | ReorderAction
  | ClearOrdersAction;

export interface OrderByAction {
  orderBy:
    | string
    | [string]
    | [string, SortDirection]
    | { column: string; direction?: SortDirection };
}

export interface OrderByDirectionAction {
  orderByDesc?: string;
  orderByAsc?: string;
}

export interface OrderByRawAction {
  orderByRaw: RawValue;
}

export interface ReorderAction {
  reorder: true;
}

export interface ClearOrdersAction {
  clearOrders: true;
}

// =============================================================================
// LIMIT ACTIONS
// =============================================================================

export type LimitAction = LimitClause | OffsetClause | ForPageClause;

export interface LimitClause {
  limit?: number | { value: number };
  take?: number | { value: number };
}

export interface OffsetClause {
  offset?: number | { value: number };
  skip?: number | { value: number };
}

export interface ForPageClause {
  forPage: [number, number] | { page: number; size: number };
}

// =============================================================================
// LOCK ACTIONS
// =============================================================================

export type LockAction =
  | LockClause
  | LockForUpdateClause
  | SharedLockClause
  | NoLockClause
  | ClearLockClause;

/** Custom lock directive */
export interface LockClause {
  lock: string;
}

/** Lock rows FOR UPDATE (exclusive lock) */
export interface LockForUpdateClause {
  lockForUpdate: true | { skipLocked?: boolean };
}

/** Shared lock - prevents modification until transaction commits */
export interface SharedLockClause {
  sharedLock: true;
}

/** SQL Server NOLOCK hint - ignore shared locks */
export interface NoLockClause {
  noLock: true;
}

/** Clear any existing lock directive */
export interface ClearLockClause {
  clearLock: true;
}

// =============================================================================
// CTE ACTIONS
// =============================================================================

export interface CTEAction {
  with?: string;
  withRecursive?: string;
  query: QBMLQuery;
}

// =============================================================================
// UNION ACTIONS
// =============================================================================

export interface UnionAction {
  union?: true;
  unionAll?: true;
  query: QBMLQuery;
}

// =============================================================================
// EXECUTOR ACTIONS
// =============================================================================

export type ExecutorAction =
  | GetExecutor
  | FirstExecutor
  | FindExecutor
  | ValueExecutor
  | ValuesExecutor
  | AggregateExecutor
  | ExistsExecutor
  | PaginateExecutor
  | ToSQLExecutor
  | DumpExecutor;

export interface ExecutorOptions {
  datasource?: string;
  timeout?: number;
  username?: string;
  password?: string;
}

export interface GetExecutor extends ExecutorOptions {
  get:
    | true
    | {
        returnFormat?: 'array' | 'tabular';
      };
}

export interface FirstExecutor extends ExecutorOptions {
  first: true;
}

export interface FindExecutor extends ExecutorOptions {
  find: number | string | [number | string, string?];
}

export interface ValueExecutor extends ExecutorOptions {
  value: string;
}

export interface ValuesExecutor extends ExecutorOptions {
  values: string;
}

export interface AggregateExecutor extends ExecutorOptions {
  count?: true | string;
  sum?: string;
  avg?: string;
  min?: string;
  max?: string;
}

export interface ExistsExecutor extends ExecutorOptions {
  exists: true;
}

export interface PaginateExecutor extends ExecutorOptions {
  paginate?: {
    page?: number;
    maxRows?: number;
    size?: number;
    returnFormat?: 'array' | 'tabular';
  };
  simplePaginate?: {
    page?: number;
    maxRows?: number;
    size?: number;
    returnFormat?: 'array' | 'tabular';
  };
}

export interface ToSQLExecutor {
  toSQL: true;
}

export interface DumpExecutor {
  dump: true;
}

// =============================================================================
// CONDITIONAL (WHEN) TYPES
// =============================================================================

export type WhenCondition =
  | 'hasValues'
  | 'notEmpty'
  | 'isEmpty'
  | ParamCondition
  | ComparisonCondition
  | LogicalCondition;

export interface ParamCondition {
  param: string;
  notEmpty?: boolean;
  isEmpty?: boolean;
  hasValue?: boolean;
  gt?: unknown;
  gte?: unknown;
  lt?: unknown;
  lte?: unknown;
  eq?: unknown;
  neq?: unknown;
}

export interface ComparisonCondition {
  notEmpty?: boolean | number;
  isEmpty?: boolean | number;
  gt?: [number, unknown];
  gte?: [number, unknown];
  lt?: [number, unknown];
  lte?: [number, unknown];
  eq?: [number, unknown];
  neq?: [number, unknown];
}

export interface LogicalCondition {
  and?: WhenCondition[];
  or?: WhenCondition[];
  not?: WhenCondition;
}

// =============================================================================
// RESULT TYPES
// =============================================================================

/** Tabular format result */
export interface TabularResult {
  columns: TabularColumn[];
  rows: unknown[][];
}

export interface TabularColumn {
  name: string;
  type:
    | 'integer'
    | 'bigint'
    | 'decimal'
    | 'varchar'
    | 'boolean'
    | 'datetime'
    | 'uuid'
    | 'object'
    | 'array';
}

/** Pagination result */
export interface PaginationResult<T = Record<string, unknown>> {
  pagination: {
    page: number;
    maxRows: number;
    totalRecords: number;
    totalPages: number;
  };
  results: T[];
}

/** Tabular pagination result */
export interface TabularPaginationResult {
  pagination: {
    page: number;
    maxRows: number;
    totalRecords: number;
    totalPages: number;
  };
  results: TabularResult;
}

// =============================================================================
// EXECUTE OPTIONS
// =============================================================================

/** Options for execute() method */
export interface QBMLExecuteOptions {
  /** Parameter values for $param references and param-based when conditions */
  params?: Record<string, unknown>;
  /** Return format: "array" (default) or "tabular" - overrides config and query definition */
  returnFormat?: 'array' | 'tabular';
  /** Database datasource to use */
  datasource?: string;
  /** Query timeout in seconds */
  timeout?: number;
  /** Database username (if not using datasource credentials) */
  username?: string;
  /** Database password (if not using datasource credentials) */
  password?: string;
}

/** QBML configuration defaults */
export interface QBMLDefaults {
  /** Query timeout in seconds */
  timeout?: number;
  /** Maximum rows to return */
  maxRows?: number;
  /** Default datasource */
  datasource?: string;
  /** Default return format: "array" or "tabular" */
  returnFormat?: 'array' | 'tabular';
}

// =============================================================================
// HELPER TYPES
// =============================================================================

/** Create a type-safe QBML query builder */
export function createQuery(): QBMLQuery {
  return [];
}

/** Type guard for ParamRef */
export function isParamRef(value: unknown): value is ParamRef {
  return (
    typeof value === 'object' &&
    value !== null &&
    '$param' in value &&
    typeof (value as ParamRef).$param === 'string'
  );
}

/** Type guard for RawExpression */
export function isRawExpression(value: unknown): value is RawExpression {
  return (
    typeof value === 'object' && value !== null && '$raw' in value
  );
}

/** Type guard to check if action has when condition */
export function isConditionalAction(
  action: QBMLAction
): action is QBMLAction & ConditionalAction {
  return 'when' in action;
}
