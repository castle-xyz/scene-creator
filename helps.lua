-- vim: set wrap linebreak breakindent showbreak=>\ :


local helps = {
    behaviors = {
        Body = {
            description = [[
Gives the actor a **position** and **angle** in the scene.

The actor is rectangle-shaped and doesn't move by default. Other behaviors can be used to change the shape or add motion.
            ]],
        },



        Image = {
            description = [[
Represents the actor **visually** with an **image**.

The source image can be **cropped** to only use a part of it.
            ]],
        },

        Drawing = {
            description = [[
Represents the actor **visually** with a drawing. You can make your own drawing or edit the current one with the **draw tool** (the pencil icon).
            ]],
        },



        CircleShape = {
            description = [[
Gives the actor a **circular collision** shape instead of the default rectangular one.
            ]],
        },



        Solid = {
            description = [[
When a moving solid runs into another solid, it's **stopped from passing through**.
            ]],
        },

        Bouncy = {
            description = [[
When a moving solid runs into another solid, it **bounces away** if either is bouncy.
            ]],
        },



        Moving = {
            description = [[
Let's the actor **move** around with **optional rotation**. The actor can be given an **initial velocity** and an **initial rotation speed**. Other behaviors can affect the motion of the actor.
            ]],
        },

        Falling = {
            description = [[
Makes the actor **fall down** due to **gravity**.
            ]],
        },

        Sliding = {
            description = [[
Limits an actor to moving along a **fixed direction**.
            ]],
        },

        Slowdown = {
            description = [[
Slows down an actor's motion and rotation over time. The slowdown for motion and rotation can be adjusted separately. Higher values slow down the actor faster.
            ]],
        },

        Friction = {
            description = [[
Makes solids **less slippery** when rubbing against each other. Both solids need to have friction for this effect. Higher friction values lead to less slipperiness.
            ]],
        },

        SpeedLimit = {
            description = [[
Sets the **maximum speed** at which the actor can move.
            ]],
        },

        RotatingMotion = {
            description = [[
**Rotates** the actor continuously.
            ]],
        },


        Sling = {
            description = [[
Allows the actor to be **slung by the user** when playing the scene. The user can **touch anywhere and pull** to define the sling direction and force.
            ]],
        },

        Drag = {
            description = [[
Allows the user to **grab the actor** and **move it directly** when playing the scene.
            ]],
        },


        Grab = {
            description = [[
A tool that allows moving and rotating actors using touch.
            ]],
        },


        Rules = {
            description = [[
A behavior that lets you **define your own rules** that tie the other behaviors of the actor together. Each rule has a **trigger** (**when** the rule should run) and a chain of **responses** (**what** the rule should do).
            ]],
        },

        Tags = {
            description = [[
Tags are used to **categorize** or **refer** to actors. Each tag is a word that you are free to choose. Tags can be used in eg. the 'collide' trigger or 'act on' responses in **rules**.
            ]],
        },

        Counter = {
            description = [[
Keep track of a **number** for this actor. **Rules** can **increase or decrease** and **check** the number. Other behaviors can **display** the number.
            ]],
        },
    },
}


return helps

