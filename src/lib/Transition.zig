// Transition.zig
const std = @import("std");

pub const TimingFunction = enum {
    linear,
    ease,
    ease_in,
    ease_out,
    ease_in_out,
    bounce,
    elastic,
};

pub const TransitionProperty = enum {
    opacity,
    x_position,
    y_position,
    width,
    height,
    rotation,
    scale,
    background_color,
    border_color,
    transform,
};

pub const TransitionState = struct {
    opacity: ?f32 = null,
    x_offset: ?f32 = null,
    y_offset: ?f32 = null,
    width_offset: ?f32 = null,
    height_offset: ?f32 = null,
    rotation: ?f32 = null,
    scale: ?f32 = null,
    background_color: ?[4]f32 = null,
    border_color: ?[4]f32 = null,
};

// Main Transition struct - holds all transition data
pub const Transition = struct {
    properties: ?[]const TransitionProperty = null,
    duration: u32 = 300, // default 300ms
    timing: TimingFunction = .ease,
    delay: u32 = 0,
    initial_state: ?TransitionState = null,
    final_state: ?TransitionState = null,

    pub fn none() Transition {
        return Transition{};
    }

    // Creator methods for built-in transitions
    pub fn fade() FadeBuilder {
        return FadeBuilder{};
    }

    pub fn slide() SlideBuilder {
        return SlideBuilder{};
    }

    pub fn zoom() ZoomBuilder {
        return ZoomBuilder{};
    }

    pub fn bounce() BounceBuilder {
        return BounceBuilder{};
    }

    pub fn flip() FlipBuilder {
        return FlipBuilder{};
    }

    pub fn rotate() RotateBuilder {
        return RotateBuilder{};
    }

    // Custom transition builder
    pub fn custom() CustomBuilder {
        return CustomBuilder{
            .transition = Transition{},
        };
    }
};

// Builder pattern for Fade transitions
pub const FadeBuilder = struct {
    duration: u32 = 300,
    timing: TimingFunction = .ease,
    delay: u32 = 0,

    pub fn In(self: FadeBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{.opacity},
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .opacity = 0,
            },
            .final_state = TransitionState{
                .opacity = 1,
            },
        };
    }

    pub fn Out(self: FadeBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{.opacity},
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .opacity = 1,
            },
            .final_state = TransitionState{
                .opacity = 0,
            },
        };
    }

    pub fn withDuration(self: FadeBuilder, ms: u32) FadeBuilder {
        var result = self;
        result.duration = ms;
        return result;
    }

    pub fn withTiming(self: FadeBuilder, timing_fn: TimingFunction) FadeBuilder {
        var result = self;
        result.timing = timing_fn;
        return result;
    }

    pub fn withDelay(self: FadeBuilder, ms: u32) FadeBuilder {
        var result = self;
        result.delay = ms;
        return result;
    }
};

// Builder pattern for Slide transitions
pub const SlideBuilder = struct {
    duration: u32 = 300,
    timing: TimingFunction = .ease,
    delay: u32 = 0,
    distance: f32 = 100, // default slide distance

    pub fn Up(self: SlideBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .y_position, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .y_offset = self.distance,
                .opacity = 0,
            },
            .final_state = TransitionState{
                .y_offset = 0,
                .opacity = 1,
            },
        };
    }

    pub fn Down(self: SlideBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .y_position, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .y_offset = -self.distance,
                .opacity = 0,
            },
            .final_state = TransitionState{
                .y_offset = 0,
                .opacity = 1,
            },
        };
    }

    pub fn Left(self: SlideBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .x_position, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .x_offset = self.distance,
                .opacity = 0,
            },
            .final_state = TransitionState{
                .x_offset = 0,
                .opacity = 1,
            },
        };
    }

    pub fn Right(self: SlideBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .x_position, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .x_offset = -self.distance,
                .opacity = 0,
            },
            .final_state = TransitionState{
                .x_offset = 0,
                .opacity = 1,
            },
        };
    }

    pub fn withDistance(self: SlideBuilder, pixels: f32) SlideBuilder {
        var result = self;
        result.distance = pixels;
        return result;
    }

    pub fn withDuration(self: SlideBuilder, ms: u32) SlideBuilder {
        var result = self;
        result.duration = ms;
        return result;
    }

    pub fn withTiming(self: SlideBuilder, timing_fn: TimingFunction) SlideBuilder {
        var result = self;
        result.timing = timing_fn;
        return result;
    }

    pub fn withDelay(self: SlideBuilder, ms: u32) SlideBuilder {
        var result = self;
        result.delay = ms;
        return result;
    }
};

// Builder pattern for Zoom transitions
pub const ZoomBuilder = struct {
    duration: u32 = 300,
    timing: TimingFunction = .ease_out,
    delay: u32 = 0,
    scale_factor: f32 = 0.3, // default zoom scale

    pub fn In(self: ZoomBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .scale, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .scale = 1.0 - self.scale_factor,
                .opacity = 0,
            },
            .final_state = TransitionState{
                .scale = 1.0,
                .opacity = 1,
            },
        };
    }

    pub fn Out(self: ZoomBuilder) Transition {
        return Transition{
            .properties = &[_]TransitionProperty{ .scale, .opacity },
            .duration = self.duration,
            .timing = self.timing,
            .delay = self.delay,
            .initial_state = TransitionState{
                .scale = 1.0,
                .opacity = 1,
            },
            .final_state = TransitionState{
                .scale = 1.0 - self.scale_factor,
                .opacity = 0,
            },
        };
    }

    pub fn withScale(self: ZoomBuilder, factor: f32) ZoomBuilder {
        var result = self;
        result.scale_factor = factor;
        return result;
    }

    pub fn withDuration(self: ZoomBuilder, ms: u32) ZoomBuilder {
        var result = self;
        result.duration = ms;
        return result;
    }

    pub fn withTiming(self: ZoomBuilder, timing_fn: TimingFunction) ZoomBuilder {
        var result = self;
        result.timing = timing_fn;
        return result;
    }

    pub fn withDelay(self: ZoomBuilder, ms: u32) ZoomBuilder {
        var result = self;
        result.delay = ms;
        return result;
    }
};

// Placeholder for other animation types - implementation would be similar
pub const BounceBuilder = struct {
    // Similar implementation to other builders
    pub fn In(_: BounceBuilder) Transition {
        return Transition{
            // Bounce animation implementation
        };
    }

    // Other methods...
};

pub const FlipBuilder = struct {
    // Similar implementation to other builders
    pub fn X(_: FlipBuilder) Transition {
        return Transition{
            // Flip animation implementation
        };
    }

    // Other methods...
};

pub const RotateBuilder = struct {
    // Similar implementation to other builders
    pub fn In(_: RotateBuilder) Transition {
        return Transition{
            // Rotate animation implementation
        };
    }

    // Other methods...
};

// For fully custom animations
pub const CustomBuilder = struct {
    transition: Transition,

    pub fn property(self: CustomBuilder, prop: TransitionProperty) CustomBuilder {
        var result = self;
        if (result.transition.properties) |props| {
            // Create a new array with the additional property
            var new_props = std.heap.page_allocator.alloc(TransitionProperty, props.len + 1) catch unreachable;
            std.mem.copy(TransitionProperty, new_props, props);
            new_props[props.len] = prop;
            result.transition.properties = new_props;
        } else {
            // Create a new array with just this property
            var new_props = std.heap.page_allocator.alloc(TransitionProperty, 1) catch unreachable;
            new_props[0] = prop;
            result.transition.properties = new_props;
        }
        return result;
    }

    pub fn duration(self: CustomBuilder, ms: u32) CustomBuilder {
        var result = self;
        result.transition.duration = ms;
        return result;
    }

    pub fn timing(self: CustomBuilder, timing_fn: TimingFunction) CustomBuilder {
        var result = self;
        result.transition.timing = timing_fn;
        return result;
    }

    pub fn delay(self: CustomBuilder, ms: u32) CustomBuilder {
        var result = self;
        result.transition.delay = ms;
        return result;
    }

    pub fn from(self: CustomBuilder, state: TransitionState) CustomBuilder {
        var result = self;
        result.transition.initial_state = state;
        return result;
    }

    pub fn to(self: CustomBuilder, state: TransitionState) CustomBuilder {
        var result = self;
        result.transition.final_state = state;
        return result;
    }

    pub fn build(self: CustomBuilder) Transition {
        return self.transition;
    }
};
