const rl = @import("raylib");
const std = @import("std");

const PI = std.math.pi;
const DEG2RAD = (PI / 180.0);
const RAD2DEG = (180.0 / PI);

const Player = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
    velocity: rl.Vector2,
    angle: f32,
    move_accel: f32,
    dash_power: f32,
    friction: f32,
};

const Obstacle = struct {
    pos: rl.Vector2,
    size: rl.Vector2,
};

pub fn main() !void {
    var dba: std.heap.DebugAllocator(.{}) = .init;
    const allocator = dba.allocator();

    {
        // Random number generator
        var prng = std.Random.DefaultPrng.init(
            blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            },
        );
        const rand = prng.random();

        // ---- WINDOW SETUP ----
        const screenWidth = 1920;
        const screenHeight = 1080;

        rl.setConfigFlags(.{
            .window_highdpi = true,
            .vsync_hint = true,
        });

        rl.initWindow(screenWidth, screenHeight, "Controfast");
        defer rl.closeWindow();
        // ---- END WINDOW SETUP ----

        // ---- TEXTURES ----
        // Player01
        const texture_player01 = try rl.loadTexture("resources/player01.png");
        defer rl.unloadTexture(texture_player01);
        // ---- END TEXTURES ----

        // Gamepad
        const gamepad_id = 0;
        // Gamepad Deadzones
        const leftStickDeadzoneX = 0.1;
        const leftStickDeadzoneY = 0.1;
        // const rightStickDeadzoneX = 0.1;
        // const rightStickDeadzoneY = 0.1;
        // const leftTriggerDeadzone = -0.9;
        const rightTriggerDeadzone = -0.9;

        var trigger_right_pressed = false;

        var prev_loop_time = rl.getTime();
        var mouse_pos = rl.Vector2.init(0, 0);

        // Player
        var player = Player{
            .pos = rl.Vector2.init(screenWidth / 2, screenHeight / 2),
            .size = rl.Vector2.init(30, 30),
            .velocity = rl.Vector2.init(0, 0),
            .angle = 270.0,
            .move_accel = 15000.0,
            .dash_power = 5000.0,
            .friction = 15.0,
        };

        var obstacles = std.ArrayList(Obstacle).init(allocator);
        defer obstacles.deinit();
        try create_random_obstacles(&obstacles, rand, 30, screenWidth, screenHeight);

        // Main game loop
        while (!rl.windowShouldClose()) {
            const loop_time = rl.getTime();
            const delta_time: f32 = @as(f32, @floatCast(loop_time)) - @as(f32, @floatCast(prev_loop_time));
            mouse_pos = rl.getMousePosition().multiply(rl.getWindowScaleDPI());

            // ---- UPDATE ----
            // Controller Input
            // Left Stick : Player Movement
            var movement_vector = rl.Vector2.init(
                rl.getGamepadAxisMovement(gamepad_id, .left_x),
                rl.getGamepadAxisMovement(gamepad_id, .left_y),
            );
            if (movement_vector.x > -leftStickDeadzoneX and movement_vector.x < leftStickDeadzoneX) {
                movement_vector.x = 0.0;
            }
            if (movement_vector.y > -leftStickDeadzoneY and movement_vector.y < leftStickDeadzoneY) {
                movement_vector.y = 0.0;
            }
            if (movement_vector.x != 0.0 or movement_vector.y != 0.0) {
                player.velocity.x += movement_vector.x * player.move_accel * delta_time;
                player.velocity.y += movement_vector.y * player.move_accel * delta_time;

                player.angle = std.math.atan2(movement_vector.y, movement_vector.x) * RAD2DEG;
            }
            // Right Trigger : Player Dash
            var trigger_right = rl.getGamepadAxisMovement(gamepad_id, .right_trigger);
            if (trigger_right < rightTriggerDeadzone) {
                trigger_right = -1.0;
            }
            if (!trigger_right_pressed and trigger_right > 0.7) {
                trigger_right_pressed = true;
                player.velocity.x = player.dash_power * @cos(player.angle * DEG2RAD);
                player.velocity.y = player.dash_power * @sin(player.angle * DEG2RAD);
            } else if (trigger_right_pressed and trigger_right < -0.5) {
                trigger_right_pressed = false;
            }
            // Facebutton
            if (rl.isGamepadButtonPressed(gamepad_id, .right_face_down)) {
                // DEBUG reset obstacles
                try create_random_obstacles(&obstacles, rand, 30, screenWidth, screenHeight);
            }

            // Player velocity
            player.pos.x += player.velocity.x * delta_time;
            player.pos.y += player.velocity.y * delta_time;
            // std.debug.print("Player velocity: {d} {d}\n", .{ player_velocity.x, player_velocity.y });

            // Player friction
            player.velocity.x -= player.velocity.x * player.friction * delta_time;
            player.velocity.y -= player.velocity.y * player.friction * delta_time;

            // Player out of bounds
            if (player.pos.x < player.size.x / 2) {
                player.pos.x = player.size.x / 2;
            }
            if (player.pos.x > screenWidth - player.size.x / 2) {
                player.pos.x = screenWidth - player.size.x / 2;
            }
            if (player.pos.y < player.size.y / 2) {
                player.pos.y = player.size.y / 2;
            }
            if (player.pos.y > screenHeight - player.size.y / 2) {
                player.pos.y = screenHeight - player.size.y / 2;
            }

            if (check_obstacle_collision(player.pos, player.size, obstacles)) {
                std.debug.print("Collision detected!\n", .{});
            }
            // ---- END UPDATE ----

            // --- DRAW ---
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(rl.Color.dark_gray);

            // player01
            const temp_color = if (player.velocity.length() > 1100.0) rl.Color.red else rl.Color.white;
            rl.drawTexturePro(
                texture_player01,
                rl.Rectangle.init(0, 0, 30, 30),
                rl.Rectangle.init(
                    player.pos.x,
                    player.pos.y,
                    30,
                    30,
                ),
                rl.Vector2.init(15, 15),
                player.angle + 90.0,
                temp_color,
            );

            // Obstacles draw
            for (obstacles.items) |obstacle| {
                rl.drawRectangleV(
                    obstacle.pos,
                    obstacle.size,
                    rl.Color.blue,
                );
            }

            // --- UI ---
            rl.drawFPS(10, 10);

            if (!rl.isGamepadAvailable(gamepad_id) and rl.getTime() > 2.0) {
                rl.drawText("No gamepad detected", 120, 10, 20, rl.Color.red);
            }

            // Wayland bug
            // Window is larger than set
            rl.drawRectangle(
                0,
                screenHeight,
                screenWidth,
                50,
                rl.Color.black,
            );
            // --- END DRAW ---

            prev_loop_time = loop_time;
        }
    }

    // Check for leaks
    if (dba.deinit() == .leak) {
        std.debug.print("Memory leak detected!\n", .{});
    } else {
        std.debug.print("No memory leaks!\n", .{});
    }
}

fn create_random_obstacles(
    array: *std.ArrayList(Obstacle),
    rand: std.Random,
    amount: usize,
    max_width: f32,
    max_height: f32,
) !void {
    array.clearAndFree();

    for (0..amount) |_| {
        try array.append(
            Obstacle{
                .pos = rl.Vector2.init(
                    rand.float(f32) * max_width,
                    rand.float(f32) * max_height,
                ),
                .size = rl.Vector2.init(
                    rand.float(f32) * 100 + 20,
                    rand.float(f32) * 100 + 20,
                ),
            },
        );
    }
}

fn check_obstacle_collision(
    player_pos: rl.Vector2,
    player_size: rl.Vector2,
    obstacles: std.ArrayList(Obstacle),
) bool {
    for (obstacles.items) |obstacle| {
        if (check_collision_circle_rect(player_pos, player_size.x / 2, obstacle.pos, obstacle.size)) {
            return true;
        }
    }
    return false;
}

pub fn check_collision_circle_rect(
    circle_pos: rl.Vector2,
    circle_radius: f32,
    rect_pos: rl.Vector2,
    rect_size: rl.Vector2,
) bool {
    const closestX = std.math.clamp(circle_pos.x, rect_pos.x, rect_pos.x + rect_size.x);
    const closestY = std.math.clamp(circle_pos.y, rect_pos.y, rect_pos.y + rect_size.y);

    const dx = circle_pos.x - closestX;
    const dy = circle_pos.y - closestY;

    return (dx * dx + dy * dy) <= (circle_radius * circle_radius);
}
