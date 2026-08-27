local Grid = require("lua/game/grid")
local Building = require("lua/game/building")

local function always_free()
    return true
end

local function never_free()
    return false
end

-- Test 1: enqueue / queue_length FIFO behavior
do
    local b = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    assert(b.id == "A", "id should equal the letter")
    assert(b.letter == "A", "letter should be stored")
    assert(b:queue_length() == 0, "queue should start empty")

    b:enqueue("B")
    assert(b:queue_length() == 1, "queue_length should be 1 after one enqueue")
    assert(b.queue[1] == "B", "first queue entry should be the first enqueued dest")

    b:enqueue("C")
    b:enqueue("D")
    assert(b:queue_length() == 3, "queue_length should be 3 after three enqueues")
    assert(b.queue[1] == "B" and b.queue[2] == "C" and b.queue[3] == "D",
        "queue should preserve FIFO insertion order")
    print("PASS: building: enqueue/queue_length FIFO behavior")
end

-- Test 2: try_spawn with a road connecting two buildings and
-- is_subcell_free always true returns a path and drains the queue by one
do
    local g = Grid.new()
    g:set_building(0, 0, "A")
    g:set_building(2, 0, "B")
    g:set_road(1, 0) -- connects A and B

    local a = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    local b = Building.new("B", 2, 0, { 0, 0, 1, 1 })
    local buildings_by_id = { A = a, B = b }

    a:enqueue("B")
    assert(a:queue_length() == 1)

    local path = a:try_spawn(g, buildings_by_id, always_free)
    assert(path ~= nil, "expected a path when a road connects the two buildings")
    assert(path[1].col == a:spawn_subcell(g).col and path[1].row == a:spawn_subcell(g).row,
        "path should start at A's spawn sub-cell")
    assert(path[#path].col == b:spawn_subcell(g).col and path[#path].row == b:spawn_subcell(g).row,
        "path should end at B's spawn sub-cell")
    assert(a:queue_length() == 0, "successful try_spawn should drain the queue by one")
    print("PASS: building: try_spawn with connecting road drains queue and returns path")
end

-- Test 3: try_spawn with no road returns nil and leaves the queue untouched
do
    local g = Grid.new()
    g:set_building(0, 0, "A")
    g:set_building(5, 5, "B")
    -- no road placed at all

    local a = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    local b = Building.new("B", 5, 5, { 0, 0, 1, 1 })
    local buildings_by_id = { A = a, B = b }

    a:enqueue("B")
    assert(a:queue_length() == 1)

    local path = a:try_spawn(g, buildings_by_id, always_free)
    assert(path == nil, "expected nil when no road connects the buildings")
    assert(a:queue_length() == 1, "queue should be untouched when no path exists")
    assert(a.queue[1] == "B", "the untouched queue entry should still be the original dest")
    print("PASS: building: try_spawn with no road returns nil, queue untouched")
end

-- Test 4: try_spawn with a valid road but is_subcell_free returning false
-- returns nil and leaves the queue untouched
do
    local g = Grid.new()
    g:set_building(0, 0, "A")
    g:set_building(2, 0, "B")
    g:set_road(1, 0)

    local a = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    local b = Building.new("B", 2, 0, { 0, 0, 1, 1 })
    local buildings_by_id = { A = a, B = b }

    a:enqueue("B")
    assert(a:queue_length() == 1)

    local path = a:try_spawn(g, buildings_by_id, never_free)
    assert(path == nil, "expected nil when is_subcell_free reports the spawn sub-cell as occupied")
    assert(a:queue_length() == 1, "queue should be untouched when spawn sub-cell is not free")
    assert(a.queue[1] == "B", "the untouched queue entry should still be the original dest")
    print("PASS: building: try_spawn with occupied spawn sub-cell returns nil, queue untouched")
end

-- Test 5: calling try_spawn repeatedly only ever removes one entry per
-- successful call
do
    local g = Grid.new()
    g:set_building(0, 0, "A")
    g:set_building(2, 0, "B")
    g:set_road(1, 0)

    local a = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    local b = Building.new("B", 2, 0, { 0, 0, 1, 1 })
    local buildings_by_id = { A = a, B = b }

    a:enqueue("B")
    a:enqueue("B")
    a:enqueue("B")
    assert(a:queue_length() == 3)

    local path1 = a:try_spawn(g, buildings_by_id, always_free)
    assert(path1 ~= nil, "first try_spawn should succeed")
    assert(a:queue_length() == 2, "queue should shrink by exactly one after first success")

    local path2 = a:try_spawn(g, buildings_by_id, always_free)
    assert(path2 ~= nil, "second try_spawn should succeed")
    assert(a:queue_length() == 1, "queue should shrink by exactly one after second success")

    local path3 = a:try_spawn(g, buildings_by_id, always_free)
    assert(path3 ~= nil, "third try_spawn should succeed")
    assert(a:queue_length() == 0, "queue should shrink by exactly one after third success")
    print("PASS: building: repeated try_spawn only removes one queue entry per success")
end

print("ALL TESTS PASSED")
