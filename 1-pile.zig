const std = @import("std");
const print = std.debug.print;

const AllocateurPile = struct {
    buffer: []u8,
    next: usize,

    /// Crée un allocateur à pile gérant la zone de mémoire délimitée
    /// par la tranche `buffer`.
    fn init(buffer: []u8) AllocateurPile {
        return .{
            .buffer = buffer,
            .next = 0,
        };
    }

    /// Retourne l’interface générique d’allocateur correspondant à
    /// cet allocateur à pile.
    fn allocator(self: *AllocateurPile) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .free = std.mem.Allocator.noFree,
                .resize = std.mem.Allocator.noResize,
                .remap = std.mem.Allocator.noRemap,
            },
        };
    }

    /// Tente d’allouer un bloc de mémoire de `len` octets dont l’adresse
    /// est alignée suivant `alignment`. Retourne un pointeur vers le début
    /// du bloc alloué, ou `null` pour indiquer un échec d’allocation.
    fn alloc(
        ctx: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        // le paramètre `return_address` peut être ignoré dans ce contexte
        _ = return_address;

        // récupère un pointeur vers l’instance de notre allocateur
        // Cast the opaque allocator context pointer to our concrete type.
        const self: *AllocateurPile = @ptrCast(@alignCast(ctx));

        // calcule l'offset aligné depuis self.next
        const start_pos = std.mem.alignForward(usize, self.next, alignment.toByteUnits());

        if (start_pos + len > self.buffer.len) {
            return null; // OutOfMemory
        }

        // met à jour next
        self.next = start_pos + len;

        const ptr: [*]u8 = @ptrCast(@alignCast(&self.buffer[start_pos]));
        return ptr;
    }
};

pub fn main() !void {
    var buffer: [4]u8 = undefined;
    var pile = AllocateurPile.init(&buffer);
    const allocator = pile.allocator();

    const a = try allocator.create(u8);
    _ = a;
    // print("{any} \n", .{@intFromPtr(a)});
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "allocations simples" {
    var buffer: [4]u8 = undefined;
    var pile = AllocateurPile.init(&buffer);
    const allocator = pile.allocator();

    const a = try allocator.create(u8);
    const b = try allocator.create(u8);
    const c = try allocator.create(u8);
    const d = try allocator.create(u8);
    const e = allocator.create(u8);

    try expect(@intFromPtr(a) + 1 <= @intFromPtr(b));
    try expect(@intFromPtr(b) + 1 <= @intFromPtr(c));
    try expect(@intFromPtr(c) + 1 <= @intFromPtr(d));
    try expectEqual(error.OutOfMemory, e);

    a.* = 4;
    b.* = 5;
    c.* = 6;
    d.* = 7;

    try expectEqual(4, a.*);
    try expectEqual(5, b.*);
    try expectEqual(6, c.*);
    try expectEqual(7, d.*);
}

test "allocations à plusieurs octets" {
    var buffer: [32]u8 = undefined;
    var pile = AllocateurPile.init(&buffer);
    const allocator = pile.allocator();

    const a = try allocator.create(u8);
    const b = try allocator.create(u64);
    const c = try allocator.create(u8);
    const d = try allocator.create(u16);

    try expect(@intFromPtr(a) + 1 <= @intFromPtr(b));
    try expect(@intFromPtr(b) + 8 <= @intFromPtr(c));
    try expect(@intFromPtr(c) + 1 <= @intFromPtr(d));

    a.* = 4;
    b.* = 5;
    c.* = 6;
    d.* = 7;

    try expectEqual(4, a.*);
    try expectEqual(5, b.*);
    try expectEqual(6, c.*);
    try expectEqual(7, d.*);
}

test "allocation de tableaux" {
    var buffer: [128]u8 = undefined;
    var pile = AllocateurPile.init(&buffer);
    const allocator = pile.allocator();

    const a = try allocator.alloc(u8, 1);
    const b = try allocator.alloc(u32, 10);
    const c = try allocator.create(u64);

    try expect(@intFromPtr(&a[0]) + 1 <= @intFromPtr(&b[0]));
    try expectEqual(10, b.len);
    try expect(@intFromPtr(&b[9]) + 4 <= @intFromPtr(c));
}
