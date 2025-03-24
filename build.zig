const std = @import("std");
const toolbox_pkg = @import("toolbox");
const Toolbox = toolbox_pkg.Toolbox;

const Paths = struct {
    __tmp: []const u8,
    __tmp_src: []const u8,
    __oniguruma: []const u8,
    __oniguruma_src: []const u8,
    __oniguruma_src_linux: []const u8,
    __oniguruma_src_windows: []const u8,

    fn getTmp(self: @This()) []const u8 {
        return self.__tmp;
    }

    fn getTmpSrc(self: @This()) []const u8 {
        return self.__tmp_src;
    }

    fn getOniguruma(self: @This()) []const u8 {
        return self.__oniguruma;
    }

    fn getOnigurumaSrc(self: @This()) []const u8 {
        return self.__oniguruma_src;
    }

    fn getOnigurumaSrcLinux(self: @This()) []const u8 {
        return self.__oniguruma_src_linux;
    }

    fn getOnigurumaSrcWindows(self: @This()) []const u8 {
        return self.__oniguruma_src_windows;
    }

    fn init(toolbox: *Toolbox) !@This() {
        const oniguruma_path = try toolbox.buildRootJoin(&.{
            "oniguruma",
        });

        const tmp_path = try toolbox.buildRootJoin(&.{
            "tmp",
        });

        const oniguruma_src_path = toolbox.pathJoin(&.{
            oniguruma_path, "src",
        });

        return .{
            .__oniguruma = oniguruma_path,
            .__tmp = tmp_path,
            .__oniguruma_src = oniguruma_src_path,
            .__oniguruma_src_linux = toolbox.pathJoin(&.{
                oniguruma_src_path, "linux",
            }),
            .__oniguruma_src_windows = toolbox.pathJoin(&.{
                oniguruma_src_path, "windows",
            }),
            .__tmp_src = toolbox.pathJoin(&.{
                tmp_path, "src",
            }),
        };
    }
};

fn update(toolbox: *Toolbox, path: *const Paths) !void {
    std.fs.deleteTreeAbsolute(path.getOniguruma()) catch |err| {
        switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    };

    try toolbox.clone(.oniguruma, path.getTmp());
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "autoreconf", "-vfi",
        },
        .cwd = path.getTmp(),
    });
    try toolbox.run(.{
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
        const dest = toolbox.pathJoin(&.{
            if (std.mem.eql(u8, entry.name, "config.h")) path.getOnigurumaSrcLinux() else path.getOnigurumaSrc(), entry.name,
        });
        switch (entry.kind) {
            .file => try toolbox.copy(toolbox.pathJoin(&.{
                path.getTmpSrc(), entry.name,
            }), dest),
            else => {},
        }
    }

    try toolbox.copy(toolbox.pathJoin(&.{
        path.getTmpSrc(), "config.h.windows.in",
    }), toolbox.pathJoin(&.{
        path.getTmpSrc(), "config.h.in",
    }));
    try toolbox.run(.{
        .argv = &[_][]const u8{
            "./configure",
        },
        .cwd = path.getTmp(),
    });

    try toolbox.copy(toolbox.pathJoin(&.{
        path.getTmpSrc(), "config.h",
    }), toolbox.pathJoin(&.{
        path.getOnigurumaSrcWindows(), "config.h",
    }));

    try std.fs.deleteTreeAbsolute(path.getTmp());
    try std.fs.deleteTreeAbsolute(toolbox.pathJoin(&.{
        path.getOnigurumaSrc(), "mktable.c",
    }));

    try toolbox.clean(&.{
        "oniguruma",
    }, &.{});
}

const FromZon = toolbox_pkg.Repositories(.{
    .toolbox,
});

const DuringExec = toolbox_pkg.Repositories(.{
    .oniguruma,
});

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    var toolbox = try Toolbox.init(FromZon, DuringExec, builder, optimize, .oniguruma_zig, "0xa8fe3aae4d9255ad", &.{
        "oniguruma",
    }, .{
        .toolbox = .{
            .name = "tiawl/toolbox",
            .host = .github,
            .ref = .tag,
        },
    }, .{
        .oniguruma = .{
            .name = "kkos/oniguruma",
            .host = .github,
            .ref = .tag,
        },
    });
    defer toolbox.deinit();

    const path = try Paths.init(&toolbox);

    if (toolbox.getUpdate()) try update(&toolbox, &path);

    const lib = builder.addStaticLibrary(.{
        .name = "oniguruma",
        .root_source_file = builder.addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    for ([_][]const u8{
        "oniguruma", builder.pathJoin(&.{
            "oniguruma", "src",
        }),
    }) |include| toolbox.addInclude(lib, include);

    toolbox.addInclude(lib, builder.pathJoin(&.{
        "oniguruma", "src", if (lib.rootModuleTarget().isMinGW()) "windows" else "linux",
    }));

    lib.linkLibC();

    toolbox.addHeader(lib, path.getOnigurumaSrc(), ".", &.{
        ".h",
    });

    var oniguruma_src_dir = try std.fs.openDirAbsolute(path.getOnigurumaSrc(), .{
        .iterate = true,
    });
    defer oniguruma_src_dir.close();

    const flags = [_][]const u8{};
    var it = oniguruma_src_dir.iterate();
    while (try it.next()) |*entry| {
        if (toolbox_pkg.isCSource(entry.name) and entry.kind == .file) {
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
