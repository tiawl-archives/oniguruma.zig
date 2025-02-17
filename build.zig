const std = @import("std");
const toolbox = @import("toolbox");

const Paths = struct {
    // prefixed attributes
    __tmp: []const u8 = undefined,
    __tmp_src: []const u8 = undefined,
    __oniguruma: []const u8 = undefined,
    __oniguruma_src: []const u8 = undefined,
    __oniguruma_src_linux: []const u8 = undefined,
    __oniguruma_src_windows: []const u8 = undefined,

    // mandatory getters
    pub fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }
    pub fn getTmpSrc(self: @This()) []const u8 {
        return self.__tmp_src;
    }
    pub fn getOniguruma(self: @This()) []const u8 {
        return self.__oniguruma;
    }
    pub fn getOnigurumaSrc(self: @This()) []const u8 {
        return self.__oniguruma_src;
    }
    pub fn getOnigurumaSrcLinux(self: @This()) []const u8 {
        return self.__oniguruma_src_linux;
    }
    pub fn getOnigurumaSrcWindows(self: @This()) []const u8 {
        return self.__oniguruma_src_windows;
    }

    // mandatory init
    pub fn init(builder: *std.Build) !@This() {
        var self = @This(){
            .__oniguruma = try builder.build_root.join(builder.allocator, &.{
                "oniguruma",
            }),
            .__tmp = try builder.build_root.join(builder.allocator, &.{
                "tmp",
            }),
        };

        self.__oniguruma_src = try std.fs.path.join(builder.allocator, &.{
            self.getOniguruma(),
            "src",
        });
        self.__oniguruma_src_linux = try std.fs.path.join(builder.allocator, &.{
            self.getOnigurumaSrc(),
            "linux",
        });
        self.__oniguruma_src_windows = try std.fs.path.join(builder.allocator, &.{
            self.getOnigurumaSrc(),
            "windows",
        });
        self.__tmp_src = try std.fs.path.join(builder.allocator, &.{
            self.getTmp(),
            "src",
        });

        return self;
    }
};

fn update(builder: *std.Build, path: *const Paths, dependencies: *const toolbox.Dependencies) !void {
    std.fs.deleteTreeAbsolute(path.getOniguruma()) catch |err|
        {
        switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    };

    try dependencies.clone(builder, "oniguruma", path.getTmp());
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "autoreconf",
            "-vfi",
        },
        .cwd = path.getTmp(),
    });
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "./configure",
        },
        .cwd = path.getTmp(),
    });

    try toolbox.make(path.getOniguruma());
    try toolbox.make(path.getOnigurumaSrc());
    try toolbox.make(path.getOnigurumaSrcLinux());
    try toolbox.make(path.getOnigurumaSrcWindows());

    var src_dir = try std.fs.openDirAbsolute(path.getTmpSrc(), .{
        .iterate = true,
    });
    defer src_dir.close();

    var it = src_dir.iterate();
    while (try it.next()) |*entry| {
        const dest = try std.fs.path.join(builder.allocator, &.{
            if (std.mem.eql(u8, entry.name, "config.h")) path.getOnigurumaSrcLinux() else path.getOnigurumaSrc(), entry.name,
        });
        switch (entry.kind) {
            .file => try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
                path.getTmpSrc(),
                entry.name,
            }), dest),
            else => {},
        }
    }

    try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
        path.getTmpSrc(),
        "config.h.windows.in",
    }), try std.fs.path.join(builder.allocator, &.{
        path.getTmpSrc(),
        "config.h.in",
    }));
    try toolbox.run(builder, .{
        .argv = &[_][]const u8{
            "./configure",
        },
        .cwd = path.getTmp(),
    });

    try toolbox.copy(try std.fs.path.join(builder.allocator, &.{
        path.getTmpSrc(),
        "config.h",
    }), try std.fs.path.join(builder.allocator, &.{
        path.getOnigurumaSrcWindows(),
        "config.h",
    }));

    try std.fs.deleteTreeAbsolute(path.getTmp());
    try std.fs.deleteTreeAbsolute(try std.fs.path.join(builder.allocator, &.{
        path.getOnigurumaSrc(),
        "mktable.c",
    }));

    try toolbox.clean(builder, &.{
        "oniguruma",
    }, &.{});
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const path = try Paths.init(builder);

    const dependencies = try toolbox.Dependencies.init(builder, "oniguruma.zig", &.{
        "oniguruma",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.tag,
        },
    }, .{
        .oniguruma = .{
            .name = "kkos/oniguruma",
            .host = toolbox.Repository.Host.github,
            .ref = toolbox.Repository.Reference.tag,
        },
    });

    if (builder.option(bool, "update", "Update binding") orelse false)
        try update(builder, &path, &dependencies);

    const lib = builder.addStaticLibrary(.{
        .name = "oniguruma",
        .root_source_file = builder.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    for ([_][]const u8{
        "oniguruma",
        try std.fs.path.join(builder.allocator, &.{
            "oniguruma",
            "src",
        }),
    }) |include| toolbox.addInclude(lib, include);

    toolbox.addInclude(lib, try std.fs.path.join(builder.allocator, &.{
        "oniguruma",                                                  "src",
        if (lib.rootModuleTarget().isMinGW()) "windows" else "linux",
    }));

    lib.linkLibC();

    toolbox.addHeader(lib, path.getOnigurumaSrc(), ".", &.{
        ".h",
    });

    var oniguruma_src_dir =
        try std.fs.openDirAbsolute(path.getOnigurumaSrc(), .{
        .iterate = true,
    });
    defer oniguruma_src_dir.close();

    const flags = [_][]const u8{};
    var it = oniguruma_src_dir.iterate();
    while (try it.next()) |*entry| {
        if (toolbox.isCSource(entry.name) and entry.kind == .file) {
            if (!std.mem.eql(u8, entry.name, "unicode_egcb_data.c") and
                !std.mem.eql(u8, entry.name, "unicode_wb_data.c") and
                !std.mem.eql(u8, entry.name, "unicode_fold_data.c") and
                !std.mem.eql(u8, entry.name, "unicode_property_data.c") and
                !std.mem.eql(u8, entry.name, "unicode_property_data_posix.c"))
            {
                try toolbox.addSource(lib, path.getOnigurumaSrc(), entry.name, &flags);
            }
        }
    }

    builder.installArtifact(lib);
}
