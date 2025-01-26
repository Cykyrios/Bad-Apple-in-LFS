# Live For Speed plays Bad Apple

[LFS_Bad_Apple.webm](https://github.com/user-attachments/assets/4adba7e2-9008-45ef-8c73-d14f044ea4ca)

Because Bad Apple is commonly recreated in any possible way, and Live For Speed now enables such a thing to come to life, I had to do it.  
This is made using my [Godot InSim](https://github.com/Cykyrios/GodotInSim) LFS InSim library and a custom mod for a light strip featuring all 7 independently controllable lights.
Put 20 of those in a grid and you get a 14x10 dot matrix (we can have up to 32 AI vehicles, if higher resolutions are needed).

Godot is then used to play the video, scaled down to said 14x10, and send commands to the AI for each frame.
