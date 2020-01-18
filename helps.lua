-- vim: set wrap linebreak breakindent showbreak=>\ :


local helps = {
    behaviors = {
        Body = {
            description = [[
Gives the actor a **position** in the scene, along with an **angle** and a **shape**. An actor **always has** this behavior and it cannot be removed.

By default, the actor is rectangle-shaped and doesn't move, but other behaviors can be used to change the shape or motion.
            ]],
        },

        Image = {
            description = [[
Represents the actor visually with an **image**.

The source image can be **cropped** to only use a part of it.
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
Makes the actor **move freely**, respond to **collisions** with other actors and (optionally) fall with **gravity**.

If an actor has a high **mass** it pushes other actors more and is pushed by other actors less.
            ]],
        },
    },
}


return helps

