const std = @import("std");
const toolbox = @import("toolbox");

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

    fn init() !@This() {
        const oniguruma_path = try toolbox.instance().getBuilder().build_root.join(toolbox.instance().getBuilder().allocator, &.{
            "oniguruma",
        });

        const tmp_path = try toolbox.instance().getBuilder().build_root.join(toolbox.instance().getBuilder().allocator, &.{
            "tmp",
        });

        const oniguruma_src_path = toolbox.instance().ptrBuilder().pathJoin(&.{
            oniguruma_path, "src",
        });

        return .{
            .__oniguruma = oniguruma_path,
            .__tmp = tmp_path,
            .__oniguruma_src = oniguruma_src_path,
            .__oniguruma_src_linux = toolbox.instance().ptrBuilder().pathJoin(&.{
                oniguruma_src_path, "linux",
            }),
            .__oniguruma_src_windows = toolbox.instance().ptrBuilder().pathJoin(&.{
                oniguruma_src_path, "windows",
            }),
            .__tmp_src = toolbox.instance().ptrBuilder().pathJoin(&.{
                tmp_path, "src",
            }),
        };
    }
};

fn update(path: *const Paths, dependencies: *const toolbox.Dependencies) !void {
    std.fs.deleteTreeAbsolute(path.getOniguruma()) catch |err| {
        switch (err) {
            error.FileNotFound => {},
            else => return err,
        }
    };

    try dependencies.clone("oniguruma", path.getTmp());
    try toolbox.instance().run(.{
        .argv = &[_][]const u8{
            "autoreconf", "-vfi",
        },
        .cwd = path.getTmp(),
    });
    try toolbox.instance().run(.{
        .argv = &[_][]const u8{
            "./configure",
        },
        .cwd = path.getTmp(),
    });

    try toolbox.instance().make(path.getOniguruma());
    try toolbox.instance().make(path.getOnigurumaSrc());
    try toolbox.instance().make(path.getOnigurumaSrcLinux());
    try toolbox.instance().make(path.getOnigurumaSrcWindows());

    var src_dir = try std.fs.openDirAbsolute(path.getTmpSrc(), .{
        .iterate = true,
    });
    defer src_dir.close();

    var it = src_dir.iterate();
    while (try it.next()) |*entry| {
        const dest = toolbox.instance().ptrBuilder().pathJoin(&.{
            if (std.mem.eql(u8, entry.name, "config.h")) path.getOnigurumaSrcLinux() else path.getOnigurumaSrc(), entry.name,
        });
        switch (entry.kind) {
            .file => try toolbox.instance().copy(toolbox.instance().ptrBuilder().pathJoin(&.{
                path.getTmpSrc(), entry.name,
            }), dest),
            else => {},
        }
    }

    try toolbox.instance().copy(toolbox.instance().ptrBuilder().pathJoin(&.{
        path.getTmpSrc(), "config.h.windows.in",
    }), toolbox.instance().ptrBuilder().pathJoin(&.{
        path.getTmpSrc(), "config.h.in",
    }));
    try toolbox.instance().run(.{
        .argv = &[_][]const u8{
            "./configure",
        },
        .cwd = path.getTmp(),
    });

    try toolbox.instance().copy(toolbox.instance().ptrBuilder().pathJoin(&.{
        path.getTmpSrc(), "config.h",
    }), toolbox.instance().ptrBuilder().pathJoin(&.{
        path.getOnigurumaSrcWindows(), "config.h",
    }));

    try std.fs.deleteTreeAbsolute(path.getTmp());
    try std.fs.deleteTreeAbsolute(toolbox.instance().ptrBuilder().pathJoin(&.{
        path.getOnigurumaSrc(), "mktable.c",
    }));

    try toolbox.instance().clean(&.{
        "oniguruma",
    }, &.{});
}

pub fn build(builder: *std.Build) !void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    toolbox.init(builder, optimize);
    defer toolbox.deinit();
    const dependencies = try toolbox.Dependencies.init(.oniguruma_zig, "0xa8fe3aae4d9255ad", &.{
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

    const path = try Paths.init();

    if (toolbox.instance().ptrBuilder().option(bool, "update", "Update binding") orelse false) {
        try update(&path, &dependencies);
    }

    const lib = toolbox.instance().ptrBuilder().addStaticLibrary(.{
        .name = "oniguruma",
        .root_source_file = toolbox.instance().ptrBuilder().addWriteFiles().add("empty.c", ""),
        .target = target,
        .optimize = optimize,
    });

    for ([_][]const u8{
        "oniguruma", toolbox.instance().ptrBuilder().pathJoin(&.{
            "oniguruma", "src",
        }),
    }) |include| toolbox.instance().addInclude(lib, include);

    toolbox.instance().addInclude(lib, toolbox.instance().ptrBuilder().pathJoin(&.{
        "oniguruma", "src", if (lib.rootModuleTarget().isMinGW()) "windows" else "linux",
    }));

    lib.linkLibC();

    toolbox.instance().addHeader(lib, path.getOnigurumaSrc(), ".", &.{
        ".h",
    });

    var oniguruma_src_dir = try std.fs.openDirAbsolute(path.getOnigurumaSrc(), .{
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
                try toolbox.instance().addSource(lib, path.getOnigurumaSrc(), entry.name, &flags);
            }
        }
    }

    toolbox.instance().ptrBuilder().installArtifact(lib);
}
