---
- name:            "wge"
  server_class:    "FCGI::Engine::Manager::Server"
  scriptname:      "#WGE_FCGI_SCRIPT_PATH"
  nproc:            #WGE_FCGI_PROC
  pidfile:         "#WGE_FCGI_PID_FILE"
  socket:          "#WGE_FCGI_HOST:#WGE_FCGI_PORT"
