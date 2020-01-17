-- vim: set wrap linebreak breakindent showbreak=>\ :


local helps = {
    behaviors = {
        Body = {
            description = [[
Gives the actor a **position** in the scene, along with an **angle** and a **shape**. The actor is given a rectangular shape by default, but other behaviors can be used to change the shape.

This behavior is required on all actors and **cannot be removed**.
            ]],
        },

        Image = {
            description = [[
Represents the actor with an **image** in the scene. The source image can be **cropped** to only use a part of it.
            ]],
        },

        Grab = {
            description = [[
A tool that allows moving and rotating actors using touch.
            ]],
        },

        RotatingMotion = {
            description = [[
**Rotates** the actor continuously.
            ]],
        },

        FreeMotion = {
            description = [[
Allows the actor to **move freely**, responding to **collisions** with other actors.

The actor can be given a **mass**. If an actor has a high mass it pushes other actors more and is pushed by other actors less.

The actor can also have **gravity**, which makes it fall downward (or upward if its gravity is negative).
            ]],
        },
    },
}


return helps

