const { createServer } = require("http");
const { Server } = require("socket.io");

const httpServer = createServer();
const io = new Server(httpServer, {
  cors: {
    origin: "*",
  },
  // transports: ["polling"],
});

io.use((socket, next) => {
  console.log("auth object for default namespace -> ", socket.handshake.auth);

  return next();
});

io.on("connection", (socket) => {
  console.log(`connected to the default namespace`);
  socket.emit("hi from server");
  socket.emit(
    "let_me_give_you_some_data",
    { name: "socket" },
    "some random message here",
    {
      family: ".io",
    }
  );

  socket.on("ping", () => {
    socket.emit("pong");
  });

  socket.on("search", (query) => {
    console.log("search -> ", query);
  });

  socket.on("disconnect", () => {
    console.log(`disconnected from default namespace`);
  });
});

const custom = io.of("/admin");
custom.use((socket, next) => {
  console.log("auth object for default namespace -> ", socket.handshake.auth);
  return next();
});

custom.on("connection", (socket) => {
  console.log(`connected to the /admin namespace`);
  socket.emit("hi from server in /admin namespace");

  socket.on("version", () => {
    socket.emit("version", { version: "4.3" });
  });

  socket.on("disconnect", () => {
    console.log(`disconnected from /admin namespace`);
  });
});

httpServer.listen(3000);
