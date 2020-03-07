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

        Drawing = {
            description = [[
Represents the actor visually with a **drawing**.
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

        Sling = {
            description = [[
Allows the actor to be slung with **user input** when the scene is being played. You can use the **free motion** behavior to adjust various properties of the actor's motion such as gravity and density.
            ]],
        },

        FreeMotion = {
            description = [[
Makes the actor **move freely** and (optionally) fall due to **gravity**. If the actor has the "solid" behavior it will be prevented from passing through other solid actors.

A higher **density** makes the actor feel heavier: it will be pushed by other actors less and push away other actors more.
            ]],
        },

        Solid = {
            description = [[
Makes the actor have a **solid surface** with **bounciness** and **friction**. This can affect motion behaviors--eg. the "free motion" behavior will prevent solid actors from passing through other solid actors.

A higher **bounciness** makes actors bounce away more when a collision occurs.

A higher **friction** makes it harder for actors to slide against each other.
            ]],
        },

        CircleShape = {
            description = [[
Gives the actor a **circular** collision shape instead of the default rectangular one.
            ]],
        }
    },
}


return helps

