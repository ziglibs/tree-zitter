const std = @import("std");

// TREE_SITTER_LANGUAGE_VERSION 14
// TREE_SITTER_MIN_COMPATIBLE_LANGUAGE_VERSION 13

pub const Symbol = enum(u16) { _ };
pub const FieldId = enum(u16) { _ };

pub const InputEncoding = enum(c_uint) {
    utf_8,
    utf_16,
};

pub const SymbolType = enum(c_uint) {
    regular,
    anonymous,
    auxiliary,
};

pub const Point = extern struct {
    row: u32,
    column: u32,
};

pub const Range = extern struct {
    start_point: Point,
    end_point: Point,
    start_byte: u32,
    end_byte: u32,
};

pub const Input = extern struct {
    payload: ?*anyopaque,
    read: ?*const fn (payload: ?*anyopaque, byte_index: u32, position: Point, bytes_read: *u32) callconv(.C) [*:0]const u8,
    encoding: InputEncoding,
};

pub const LogType = enum(c_uint) {
    parse,
    lex,
};

pub const Logger = extern struct {
    payload: ?*anyopaque,
    log: ?*const fn (payload: ?*anyopaque, log_type: LogType, log: [*:0]const u8) callconv(.C) void,
};

pub const InputEdit = extern struct {
    start_byte: u32,
    old_end_byte: u32,
    new_end_byte: u32,
    start_point: Point,
    old_end_point: Point,
    new_end_point: Point,
};

// pub const TreeCursor = extern struct {
//     tree: ?*const anyopaque,
//     id: ?*const anyopaque,
//     context: [2]u32,
// };

pub const Quantifier = enum(c_uint) {
    zero,
    zero_or_one,
    zero_or_more,
    one,
    one_or_more,
};

pub const QueryPredicateStepType = enum(c_uint) {
    done,
    capture,
    string,
};

pub const QueryPredicateStep = extern struct {
    type: QueryPredicateStepType,
    value_id: u32,
};

// Parser

pub const Language = opaque {
    pub const GetError = error{Unknown};
    pub fn get(comptime language_name: []const u8) GetError!*const Language {
        const ext = @extern(?*const fn () callconv(.C) ?*const Language, .{
            .name = std.fmt.comptimePrint("tree_sitter_{s}", .{language_name}),
        }) orelse @compileError(std.fmt.comptimePrint("Cannot find extern tree_sitter_{s}", .{language_name}));

        return ext() orelse error.Unknown;
    }
};

pub const Parser = opaque {
    pub const InitError = error{Unknown};
    pub fn create() InitError!*Parser {
        return ts_parser_new() orelse return error.Unknown;
    }

    pub fn destroy(parser: *Parser) void {
        ts_parser_delete(parser);
    }

    pub const SetLanguageError = error{VersionMismatch};
    pub fn setLanguage(parser: *Parser, language: *const Language) SetLanguageError!void {
        if (!ts_parser_set_language(parser, language))
            return error.VersionMismatch;
    }

    pub fn getLanguage(parser: *Parser) ?*const Language {
        return if (ts_parser_language(parser)) |language|
            language
        else
            null;
    }

    pub const SetIncludedRangesError = error{Unknown};
    pub fn setIncludedRanges(parser: *Parser, ranges: []const Range) void {
        if (!ts_parser_set_included_ranges(parser, ranges.ptr, @intCast(u32, ranges.len)))
            return error.Unknown;
    }

    pub fn getIncludedRanges(parser: *Parser) []const Range {
        var length: u32 = 0;
        return ts_parser_included_ranges(parser, &length)[0..length];
    }

    pub const ParseError = error{ NoLanguage, Unknown };
    pub fn parse(parser: Parser, old_tree: ?*Tree, input: Input) ParseError!*Tree {
        return if (ts_parser_parse(parser, old_tree, input)) |tree|
            tree
        else
            (if (parser.getLanguage()) |_|
                error.Unknown
            else
                error.NoLanguage);
    }

    pub fn parseString(parser: *Parser, old_tree: ?*Tree, string: []const u8) ParseError!*Tree {
        return if (ts_parser_parse_string(parser, old_tree, string.ptr, @intCast(u32, string.len))) |tree|
            tree
        else
            (if (parser.getLanguage()) |_|
                error.Unknown
            else
                error.NoLanguage);
    }

    pub fn parseStringWithEncoding(parser: *Parser, old_tree: ?*Tree, string: []const u8, encoding: InputEncoding) ParseError!*Tree {
        return if (ts_parser_parse_string(parser, old_tree, string.ptr, @intCast(u32, string.len), encoding)) |tree|
            tree
        else
            (if (parser.getLanguage()) |_|
                error.Unknown
            else
                error.NoLanguage);
    }

    pub fn reset(parser: *Parser) void {
        ts_parser_reset(parser);
    }

    pub fn setTimeout(parser: *Parser, microseconds: u64) void {
        ts_parser_set_timeout_micros(parser, microseconds);
    }

    pub fn getTimeout(parser: *Parser) u64 {
        return ts_parser_timeout_micros(parser);
    }

    pub fn setCancellationFlag(parser: *Parser, flag: ?*const usize) void {
        ts_parser_set_cancellation_flag(parser, flag);
    }

    pub fn getCancellationFlag(parser: *Parser) ?*const usize {
        return ts_parser_cancellation_flag(parser);
    }

    pub fn setLogger(parser: *Parser, logger: Logger) void {
        ts_parser_set_logger(parser, logger);
    }

    pub fn getLogger(parser: *Parser) Logger {
        return ts_parser_logger(parser);
    }

    pub fn printDotGraphs(parser: *Parser, file: std.fs.File) void {
        ts_parser_print_dot_graphs(parser, file.handle);
    }
};

pub const Tree = opaque {
    pub const DupeError = error{Unknown};
    pub fn dupe(tree: *Tree) DupeError!*Tree {
        return ts_tree_copy(tree) orelse return error.Unknown;
    }

    pub fn destroy(tree: *Tree) void {
        ts_tree_delete(tree);
    }

    pub fn getRootNode(tree: *Tree) Node {
        return ts_tree_root_node(tree);
    }

    pub fn getRootNodeWithOffset(tree: *Tree, offset_bytes: u32, offset_point: Point) Node {
        return .ts_tree_root_node_with_offset(tree, offset_bytes, offset_point);
    }

    pub fn getLanguage(tree: *Tree) *const Language {
        return ts_tree_language(tree).?;
    }

    pub fn getIncludedRanges(tree: *Tree) []const Range {
        var length: u32 = 0;
        return ts_tree_included_ranges(tree, &length)[0..length];
    }

    /// Apply a text diff to the tree
    pub fn edit(tree: *Tree, the_edit: *const InputEdit) void {
        ts_tree_edit(tree, the_edit);
    }

    pub fn getChangedRanges(old: *Tree, new: *Tree) []const Range {
        var length: u32 = 0;
        return ts_tree_get_changed_ranges(old, new, &length)[0..length];
    }

    pub fn printDotGraph(tree: *Tree, file: std.fs.File) void {
        ts_tree_print_dot_graph(tree, file.handle);
    }
};

pub const Node = extern struct {
    context: [4]u32,
    id: ?*const anyopaque,
    tree: ?*const Tree,

    pub const ChildIterator = struct {
        node: Node,
        index: u32 = 0,

        pub fn next(iterator: ChildIterator) ?Node {
            defer iterator.index += 1;

            var maybe_child = iterator.node.getChild(iterator.index);
            return if (maybe_child.isNull())
                null
            else
                maybe_child;
        }
    };

    pub const NamedChildIterator = struct {
        node: Node,
        index: u32 = 0,

        pub fn next(iterator: NamedChildIterator) ?Node {
            defer iterator.index += 1;

            var maybe_child = iterator.node.getNamedChild(iterator.index);
            return if (maybe_child.isNull())
                null
            else
                maybe_child;
        }
    };

    pub fn getTree(node: Node) Tree {
        return node.tree.?;
    }

    pub fn getType(node: Node) []const u8 {
        return std.mem.span(ts_node_type(node));
    }

    pub fn getSymbol(node: Node) Symbol {
        return ts_node_symbol(node);
    }

    pub fn getStartByte(node: Node) u32 {
        return ts_node_start_byte(node);
    }

    pub fn getStartPoint(node: Node) Point {
        return ts_node_start_point(node);
    }

    pub fn getEndByte(node: Node) u32 {
        return ts_node_end_byte(node);
    }

    pub fn getEndPoint(node: Node) Point {
        return ts_node_end_point(node);
    }

    /// Caller must call `freeSExpressionString` when done
    pub fn asSExpressionString(node: Node) []const u8 {
        return std.mem.span(ts_node_string(node));
    }

    pub fn freeSExpressionString(str: []const u8) void {
        // TODO: Use allocator + set_allocator
        std.free(@ptrCast(*anyopaque, @constCast(str.ptr)));
    }

    pub fn format(node: Node, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        const str = node.asSExpressionString();
        try writer.print("Node({s})", .{str});
        defer freeSExpressionString(str);
    }

    pub fn isNull(node: Node) bool {
        return ts_node_is_null(node);
    }

    pub fn isNamed(node: Node) bool {
        return ts_node_is_named(node);
    }

    pub fn isMissing(node: Node) bool {
        return ts_node_is_missing(node);
    }

    pub fn isExtra(node: Node) bool {
        return ts_node_is_extra(node);
    }

    pub fn hasChanges(node: Node) bool {
        return ts_node_has_changes(node);
    }

    pub fn hasError(node: Node) bool {
        return ts_node_has_error(node);
    }

    /// Remember to check with isNull (root)
    pub fn getParent(node: Node) Node {
        return ts_node_parent(node);
    }

    /// Remember to check with isNull
    pub fn getChild(node: Node, child_index: u32) Node {
        return ts_node_child(node, child_index);
    }

    /// NOTE: If you're iterating with this frequently,
    /// you should be using TreeCursor
    pub fn childIterator(node: Node) ChildIterator {
        return ChildIterator{ .node = node };
    }

    pub fn getFieldNameForChild(node: Node, child_index: u32) ?[]const u8 {
        return std.mem.span(ts_node_field_name_for_child(node, child_index) orelse return null);
    }

    pub fn getChildCount(node: Node) u32 {
        return ts_node_child_count(node);
    }

    /// Remember to check with isNull
    pub fn getNamedChild(node: Node, child_index: u32) Node {
        return ts_node_named_child(node, child_index);
    }

    /// NOTE: If you're iterating with this frequently,
    /// you should be using TreeCursor
    pub fn namedChildIterator(node: Node) NamedChildIterator {
        return NamedChildIterator{ .node = node };
    }

    pub fn getNamedChildCount(node: Node) u32 {
        return ts_node_named_child_count(node);
    }

    /// Remember to check with isNull
    pub fn getChildByFieldName(node: Node, field_name: []const u8) Node {
        return ts_node_child_by_field_name(node, field_name.ptr, @intCast(u32, field_name.len));
    }

    /// Remember to check with isNull
    pub fn getChildByFieldId(node: Node, field_id: FieldId) Node {
        return ts_node_child_by_field_name(node, field_id);
    }

    // TODO: Sibling iterators

    pub fn nextSibling(node: Node) Node {
        return ts_node_next_sibling(node);
    }

    pub fn prevSibling(node: Node) Node {
        return ts_node_prev_sibling(node);
    }

    pub fn nextNamedSibling(node: Node) Node {
        return ts_node_next_named_sibling(node);
    }

    pub fn prevNamedSibling(node: Node) Node {
        return ts_node_prev_named_sibling(node);
    }

    // TODO: Niche and I'm lazy
    // pub extern fn ts_node_first_child_for_byte(Node, u32) Node;
    // pub extern fn ts_node_first_named_child_for_byte(Node, u32) Node;
    // pub extern fn ts_node_descendant_for_byte_range(Node, u32, u32) Node;
    // pub extern fn ts_node_descendant_for_point_range(Node, Point, Point) Node;
    // pub extern fn ts_node_named_descendant_for_byte_range(Node, u32, u32) Node;
    // pub extern fn ts_node_named_descendant_for_point_range(Node, Point, Point) Node;

    /// Apply a text diff to the node
    pub fn edit(node: Node, the_edit: *const InputEdit) void {
        ts_node_edit(node, the_edit);
    }

    pub fn eql(a: Node, b: Node) bool {
        return ts_node_eq(a, b);
    }
};

// TODO: TreeCursor

pub const Query = opaque {
    const ErrorValues = enum(c_uint) {
        none,
        syntax,
        node_type,
        field,
        capture,
        structure,
        language,
    };

    pub const CreateError = error{
        InvalidSyntax,
        InvalidNodeType,
        InvalidField,
        InvalidCapture,
        InvalidStructure,
        InvalidLanguage,
    };

    pub fn create(
        language: *const Language,
        source: []const u8,
    ) CreateError!*Query {
        var error_offset: u32 = 0;
        var error_type: ErrorValues = .none;

        return if (ts_query_new(language, source.ptr, @intCast(u32, source.len), &error_offset, &error_type)) |query|
            query
        else switch (error_type) {
            .none => unreachable,
            .syntax => error.InvalidSyntax,
            .node_type => error.InvalidNodeType,
            .field => error.InvalidField,
            .capture => error.InvalidCapture,
            .structure => error.InvalidStructure,
            .language => error.InvalidLanguage,
        };
    }

    pub fn destroy(query: *Query) void {
        ts_query_delete(query);
    }

    // TODO: Implement these
    // pub extern fn ts_query_pattern_count(?*const Query) u32;
    // pub extern fn ts_query_capture_count(?*const Query) u32;
    // pub extern fn ts_query_string_count(?*const Query) u32;
    // pub extern fn ts_query_start_byte_for_pattern(?*const Query, u32) u32;
    // pub extern fn ts_query_predicates_for_pattern(self: ?*const Query, pattern_index: u32, length: [*c]u32) [*c]const QueryPredicateStep;
    // pub extern fn ts_query_is_pattern_rooted(self: ?*const Query, pattern_index: u32) bool;
    // pub extern fn ts_query_is_pattern_non_local(self: ?*const Query, pattern_index: u32) bool;
    // pub extern fn ts_query_is_pattern_guaranteed_at_step(self: ?*const Query, byte_offset: u32) bool;
    // pub extern fn ts_query_capture_name_for_id(?*const Query, id: u32, length: [*c]u32) [*c]const u8;
    // pub extern fn ts_query_capture_quantifier_for_id(?*const Query, pattern_id: u32, capture_id: u32) Quantifier;
    // pub extern fn ts_query_string_value_for_id(?*const Query, id: u32, length: [*c]u32) [*c]const u8;
    // pub extern fn ts_query_disable_capture(?*Query, [*c]const u8, u32) void;
    // pub extern fn ts_query_disable_pattern(?*Query, u32) void;

    pub const Match = extern struct {
        id: u32,
        pattern_index: u16,
        captures_len: u16,
        captures_ptr: [*]const Capture,

        pub fn captures(match: Match) []const Capture {
            return match.captures_ptr[0..match.captures_len];
        }
    };

    pub const Capture = extern struct {
        node: Node,
        index: u32,
    };

    pub const Cursor = opaque {
        pub const CursorCreateError = error{Unknown};
        pub fn create() CursorCreateError!*Cursor {
            return ts_query_cursor_new() orelse return error.Unknown;
        }

        pub fn destroy(cursor: *Cursor) void {
            ts_query_cursor_delete(cursor);
        }

        pub fn execute(cursor: *Cursor, query: *const Query, node: Node) void {
            ts_query_cursor_exec(cursor, query, node);
        }

        pub fn nextMatch(cursor: *Cursor) ?Match {
            var match: Query.Match = undefined;
            return if (ts_query_cursor_next_match(cursor, &match))
                match
            else
                null;
        }

        pub fn nextCapture(cursor: *Cursor) ?Capture {
            var match: Query.Match = undefined;
            var capture_index: u32 = 0;
            return if (ts_query_cursor_next_capture(cursor, &match, &capture_index))
                match.captures()[capture_index]
            else
                null;
        }

        // TODO: Implement these
        // pub extern fn ts_query_cursor_did_exceed_match_limit(?*const Cursor) bool;
        // pub extern fn ts_query_cursor_match_limit(?*const Cursor) u32;
        // pub extern fn ts_query_cursor_set_match_limit(?*Cursor, u32) void;
        // pub extern fn ts_query_cursor_set_byte_range(?*Cursor, u32, u32) void;
        // pub extern fn ts_query_cursor_set_point_range(?*Cursor, Point, Point) void;
        // pub extern fn ts_query_cursor_next_match(?*Cursor, match: [*c]Query.Match) bool;
        // pub extern fn ts_query_cursor_remove_match(?*Cursor, id: u32) void;
        // pub extern fn ts_query_cursor_next_capture(?*Cursor, match: [*c]Query.Match, capture_index: [*c]u32) bool;
    };
};

// TODO: set allocator

// TODO: Move these to appropriate structs
pub extern fn ts_parser_new() ?*Parser;
pub extern fn ts_parser_delete(parser: ?*Parser) void;
pub extern fn ts_parser_set_language(self: ?*Parser, language: ?*const Language) bool;
pub extern fn ts_parser_language(self: ?*const Parser) ?*const Language;
pub extern fn ts_parser_set_included_ranges(self: ?*Parser, ranges: [*]const Range, length: u32) bool;
pub extern fn ts_parser_included_ranges(self: ?*const Parser, length: *u32) [*]const Range;
pub extern fn ts_parser_parse(self: ?*Parser, old_tree: ?*const Tree, input: Input) ?*Tree;
pub extern fn ts_parser_parse_string(self: ?*Parser, old_tree: ?*const Tree, string: [*]const u8, length: u32) ?*Tree;
pub extern fn ts_parser_parse_string_encoding(self: ?*Parser, old_tree: ?*const Tree, string: [*]const u8, length: u32, encoding: InputEncoding) ?*Tree;
pub extern fn ts_parser_reset(self: ?*Parser) void;
pub extern fn ts_parser_set_timeout_micros(self: ?*Parser, timeout: u64) void;
pub extern fn ts_parser_timeout_micros(self: ?*const Parser) u64;
pub extern fn ts_parser_set_cancellation_flag(self: ?*Parser, flag: ?*const usize) void;
pub extern fn ts_parser_cancellation_flag(self: ?*const Parser) ?*const usize;
pub extern fn ts_parser_set_logger(self: ?*Parser, logger: Logger) void;
pub extern fn ts_parser_logger(self: ?*const Parser) Logger;
pub extern fn ts_parser_print_dot_graphs(self: ?*Parser, file: c_int) void;

pub extern fn ts_tree_copy(self: ?*const Tree) ?*Tree;
pub extern fn ts_tree_delete(self: ?*Tree) void;
pub extern fn ts_tree_root_node(self: ?*const Tree) Node;
pub extern fn ts_tree_root_node_with_offset(self: ?*const Tree, offset_bytes: u32, offset_point: Point) Node;
pub extern fn ts_tree_language(?*const Tree) ?*const Language;
pub extern fn ts_tree_included_ranges(?*const Tree, length: *u32) [*]Range;
pub extern fn ts_tree_edit(self: ?*Tree, edit: *const InputEdit) void;
pub extern fn ts_tree_get_changed_ranges(old_tree: ?*const Tree, new_tree: ?*const Tree, length: *u32) [*]Range;
pub extern fn ts_tree_print_dot_graph(?*const Tree, file_descriptor: c_int) void;

pub extern fn ts_node_type(Node) [*:0]const u8;
pub extern fn ts_node_symbol(Node) Symbol;
pub extern fn ts_node_start_byte(Node) u32;
pub extern fn ts_node_start_point(Node) Point;
pub extern fn ts_node_end_byte(Node) u32;
pub extern fn ts_node_end_point(Node) Point;
pub extern fn ts_node_string(Node) [*:0]u8;
pub extern fn ts_node_is_null(Node) bool;
pub extern fn ts_node_is_named(Node) bool;
pub extern fn ts_node_is_missing(Node) bool;
pub extern fn ts_node_is_extra(Node) bool;
pub extern fn ts_node_has_changes(Node) bool;
pub extern fn ts_node_has_error(Node) bool;
pub extern fn ts_node_parent(Node) Node;
pub extern fn ts_node_child(Node, u32) Node;
pub extern fn ts_node_field_name_for_child(Node, u32) ?[*:0]const u8;
pub extern fn ts_node_child_count(Node) u32;
pub extern fn ts_node_named_child(Node, u32) Node;
pub extern fn ts_node_named_child_count(Node) u32;
pub extern fn ts_node_child_by_field_name(self: Node, field_name: [*]const u8, field_name_length: u32) Node;
pub extern fn ts_node_child_by_field_id(Node, FieldId) Node;
pub extern fn ts_node_next_sibling(Node) Node;
pub extern fn ts_node_prev_sibling(Node) Node;
pub extern fn ts_node_next_named_sibling(Node) Node;
pub extern fn ts_node_prev_named_sibling(Node) Node;
pub extern fn ts_node_first_child_for_byte(Node, u32) Node;
pub extern fn ts_node_first_named_child_for_byte(Node, u32) Node;
pub extern fn ts_node_descendant_for_byte_range(Node, u32, u32) Node;
pub extern fn ts_node_descendant_for_point_range(Node, Point, Point) Node;
pub extern fn ts_node_named_descendant_for_byte_range(Node, u32, u32) Node;
pub extern fn ts_node_named_descendant_for_point_range(Node, Point, Point) Node;
pub extern fn ts_node_edit(*Node, *const InputEdit) void;
pub extern fn ts_node_eq(Node, Node) bool;

// pub extern fn ts_tree_cursor_new(Node) TreeCursor;
// pub extern fn ts_tree_cursor_delete([*c]TreeCursor) void;
// pub extern fn ts_tree_cursor_reset([*c]TreeCursor, Node) void;
// pub extern fn ts_tree_cursor_current_node([*c]const TreeCursor) Node;
// pub extern fn ts_tree_cursor_current_field_name([*c]const TreeCursor) [*c]const u8;
// pub extern fn ts_tree_cursor_current_field_id([*c]const TreeCursor) FieldId;
// pub extern fn ts_tree_cursor_goto_parent([*c]TreeCursor) bool;
// pub extern fn ts_tree_cursor_goto_next_sibling([*c]TreeCursor) bool;
// pub extern fn ts_tree_cursor_goto_first_child([*c]TreeCursor) bool;
// pub extern fn ts_tree_cursor_goto_first_child_for_byte([*c]TreeCursor, u32) i64;
// pub extern fn ts_tree_cursor_goto_first_child_for_point([*c]TreeCursor, Point) i64;
// pub extern fn ts_tree_cursor_copy([*c]const TreeCursor) TreeCursor;

pub extern fn ts_query_new(language: ?*const Language, source: [*]const u8, source_len: u32, error_offset: *u32, error_type: *Query.ErrorValues) ?*Query;
pub extern fn ts_query_delete(?*Query) void;
pub extern fn ts_query_pattern_count(?*const Query) u32;
pub extern fn ts_query_capture_count(?*const Query) u32;
pub extern fn ts_query_string_count(?*const Query) u32;
pub extern fn ts_query_start_byte_for_pattern(?*const Query, u32) u32;
pub extern fn ts_query_predicates_for_pattern(self: ?*const Query, pattern_index: u32, length: [*c]u32) [*c]const QueryPredicateStep;
pub extern fn ts_query_is_pattern_rooted(self: ?*const Query, pattern_index: u32) bool;
pub extern fn ts_query_is_pattern_non_local(self: ?*const Query, pattern_index: u32) bool;
pub extern fn ts_query_is_pattern_guaranteed_at_step(self: ?*const Query, byte_offset: u32) bool;
pub extern fn ts_query_capture_name_for_id(?*const Query, id: u32, length: [*c]u32) [*c]const u8;
pub extern fn ts_query_capture_quantifier_for_id(?*const Query, pattern_id: u32, capture_id: u32) Quantifier;
pub extern fn ts_query_string_value_for_id(?*const Query, id: u32, length: [*c]u32) [*c]const u8;
pub extern fn ts_query_disable_capture(?*Query, [*c]const u8, u32) void;
pub extern fn ts_query_disable_pattern(?*Query, u32) void;

pub extern fn ts_query_cursor_new() ?*Query.Cursor;
pub extern fn ts_query_cursor_delete(?*Query.Cursor) void;
pub extern fn ts_query_cursor_exec(?*Query.Cursor, ?*const Query, Node) void;
pub extern fn ts_query_cursor_did_exceed_match_limit(?*const Query.Cursor) bool;
pub extern fn ts_query_cursor_match_limit(?*const Query.Cursor) u32;
pub extern fn ts_query_cursor_set_match_limit(?*Query.Cursor, u32) void;
pub extern fn ts_query_cursor_set_byte_range(?*Query.Cursor, u32, u32) void;
pub extern fn ts_query_cursor_set_point_range(?*Query.Cursor, Point, Point) void;
pub extern fn ts_query_cursor_next_match(?*Query.Cursor, match: [*c]Query.Match) bool;
pub extern fn ts_query_cursor_remove_match(?*Query.Cursor, id: u32) void;
pub extern fn ts_query_cursor_next_capture(?*Query.Cursor, match: *Query.Match, capture_index: *u32) bool;

pub extern fn ts_language_symbol_count(?*const Language) u32;
pub extern fn ts_language_symbol_name(?*const Language, Symbol) [*c]const u8;
pub extern fn ts_language_symbol_for_name(self: ?*const Language, string: [*c]const u8, length: u32, is_named: bool) Symbol;
pub extern fn ts_language_field_count(?*const Language) u32;
pub extern fn ts_language_field_name_for_id(?*const Language, FieldId) [*c]const u8;
pub extern fn ts_language_field_id_for_name(?*const Language, [*c]const u8, u32) FieldId;
pub extern fn ts_language_symbol_type(?*const Language, Symbol) SymbolType;
pub extern fn ts_language_version(?*const Language) u32;

pub extern fn ts_set_allocator(new_malloc: ?*const fn (usize) callconv(.C) ?*anyopaque, new_calloc: ?*const fn (usize, usize) callconv(.C) ?*anyopaque, new_realloc: ?*const fn (?*anyopaque, usize) callconv(.C) ?*anyopaque, new_free: ?*const fn (?*anyopaque) callconv(.C) void) void;