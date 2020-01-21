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
Makes the actor **move freely** and (optionally) fall due to **gravity**. If the actor has the "solid" behavior it will be prevented from passing through other solid actors.
            ]],
        },

        Solid = {
            description = [[
Makes the actor have a **solid surface** with **bounciness** and **friction**. Motion behaviors may then use these properties--eg. the "free motion" behavior will prevent solid actors from passing through other solid actors.

A higher **bounciness** makes actors bounce away more when a collision occurs. When two actors collide, the higher bounciness value between the two is used to decide how bouncy the collision is. This way you can make a bouncy ball without having to make the floor bouncy too.

A higher **friction** makes it harder for actors to slide against each other.
            ]],
        },
    },
}


return helps

