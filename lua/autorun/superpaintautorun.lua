if SERVER then util.AddNetworkString("superpaint_nmsg") end

CreateConVar("superpaint_maxpaints", 32, FCVAR_REPLICATED, "Max super paint decals allowed per prop. Superadmins are not affected.", 1, 16384)

duplicator.RegisterEntityModifier( "superpaintsave", function(ply, ent, data) 
    for _, pdat in pairs(data) do
        DoSuperPaint(ent, unpack(pdat))
    end
end)

function DoSuperPaint(ent, mat, startpos, endpos, width, height)
    if SERVER then
        ent.superpaints = ent.superpaints or {}

        net.Start("superpaint_nmsg")
        net.WriteEntity(ent)
        net.WriteString(mat)
        net.WriteVector(startpos)
        net.WriteVector(endpos)
        net.WriteFloat(math.Clamp(math.Round(width, 2), 0.01, 1024))
        net.WriteFloat(math.Clamp(math.Round(height, 2), 0.01, 1024))
        net.Broadcast()

        if ent:GetClass() == "prop_physics" then
            table.insert(ent.superpaints, {mat, startpos, endpos, width, height})
            duplicator.StoreEntityModifier(ent, "superpaintsave", ent.superpaints)
        end
    else
        local ltwS = ent:LocalToWorld(startpos)
        local ltwE = ent:LocalToWorld(endpos)
        local dir =  (ltwE - ltwS):Angle():Forward()
        local tr = util.TraceLine({
            start = ltwS,
            endpos = ltwS + dir * 16384,
            filter = player.GetAll()
        })

        util.DecalEx(Material(mat), ent, ltwE, tr.HitNormal, color_white, width, height)
    end
end

if CLIENT then
    net.Receive("superpaint_nmsg", function()
        DoSuperPaint(net.ReadEntity(), net.ReadString(), net.ReadVector(), net.ReadVector(), net.ReadFloat(), net.ReadFloat())
    end)
end