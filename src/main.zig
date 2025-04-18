const rl = @import("raylib");
const std = @import("std");

const PI = std.math.pi;
const DEG2RAD = (PI / 180.0);
const RAD2DEG = (180.0 / PI);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    _ = allocator;

    {

        // ---- WINDOW SETUP ----
        const screenWidth = 1920;
        const screenHeight = 1080;

        rl.setConfigFlags(.{
            .window_highdpi = true,
            .vsync_hint = true,
            .msaa_4x_hint = true,
        });

        rl.initWindow(screenWidth, screenHeight, "Controfast");
        defer rl.closeWindow();
        // ---- END WINDOW SETUP ----

        // ---- TEXTURES ----
        // Player01
        const img_player01 = try rl.loadImage("resources/player01.png");
        const texture_player01 = try rl.loadTextureFromImage(img_player01);
        defer rl.unloadTexture(texture_player01);
        rl.unloadImage(img_player01);
        // ---- END TEXTURES ----

        // Gamepad
        const gamepad_id = 0;
        // Controller Deadzones
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
        var player_pos = rl.Vector2.init(100, 100);
        var player_velocity = rl.Vector2.init(0, 0);
        const player_move_accel = 15000.0;
        const player_dash_power = 5000.0;
        const player_friction = 15;
        var player_angle: f32 = 0.0;

        // Main game loop
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
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
                player_velocity.x += movement_vector.x * player_move_accel * delta_time;
                player_velocity.y += movement_vector.y * player_move_accel * delta_time;

                player_angle = std.math.atan2(movement_vector.y, movement_vector.x) * RAD2DEG;
            }
            // Right Trigger : Player Dash
            var trigger_right = rl.getGamepadAxisMovement(gamepad_id, .right_trigger);
            if (trigger_right < rightTriggerDeadzone) {
                trigger_right = -1.0;
            }
            if (!trigger_right_pressed and trigger_right > 0.7) {
                trigger_right_pressed = true;
                player_velocity.x = player_dash_power * @cos(player_angle * DEG2RAD);
                player_velocity.y = player_dash_power * @sin(player_angle * DEG2RAD);
            } else if (trigger_right_pressed and trigger_right < -0.5) {
                trigger_right_pressed = false;
            }

            // Player velocity
            player_pos.x += player_velocity.x * delta_time;
            player_pos.y += player_velocity.y * delta_time;
            // std.debug.print("Player velocity: {d} {d}\n", .{ player_velocity.x, player_velocity.y });

            // Player friction
            player_velocity.x -= player_velocity.x * player_friction * delta_time;
            player_velocity.y -= player_velocity.y * player_friction * delta_time;

            // Player out of bounds
            if (player_pos.x < 15) {
                player_pos.x = 15;
            }
            if (player_pos.x > screenWidth - 15) {
                player_pos.x = screenWidth - 15;
            }
            if (player_pos.y < 15) {
                player_pos.y = 15;
            }
            if (player_pos.y > screenHeight - 15) {
                player_pos.y = screenHeight - 15;
            }
            // ---- END UPDATE ----

            // --- DRAW ---
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(rl.Color.dark_gray);

            // player01
            const temp_color = if (player_velocity.length() > 1100.0) rl.Color.red else rl.Color.white;

            rl.drawTexturePro(
                texture_player01,
                rl.Rectangle.init(0, 0, 30, 30),
                rl.Rectangle.init(
                    player_pos.x,
                    player_pos.y,
                    30,
                    30,
                ),
                rl.Vector2.init(15, 15),
                player_angle + 90.0,
                temp_color,
            );

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
    if (gpa.deinit() == .leak) {
        std.debug.print("Memory leak detected!\n", .{});
    } else {
        std.debug.print("No memory leaks!\n", .{});
    }
}
