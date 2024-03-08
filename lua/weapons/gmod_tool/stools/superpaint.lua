TOOL.Category = "Render"
TOOL.Name = "Super Paint"

TOOL.ClientConVar["mat"] = "lights/white"
TOOL.ClientConVar["width"] = 1
TOOL.ClientConVar["height"] = 1

TOOL.PreviewMat = Material("models/debug/debugwhite")

if CLIENT then
    hook.Add("InitPostEntity", "superpaint_cvarshit", function()
        timer.Simple(1, function()
            LocalPlayer():GetTool("superpaint").PreviewMat = Material(GetConVar("superpaint_mat"):GetString())
        end)

        cvars.AddChangeCallback("superpaint_mat", function(_, _, newmat)
            LocalPlayer():GetTool("superpaint").PreviewMat = Material(newmat)
        end, "superpaint_changepreviewmat")
    end)
end

function TOOL:LeftClick( trace )
    if SERVER then
        if string.lower(Material(self:GetClientInfo("mat")):GetShader()) == "lightmappedgeneric" then self:GetOwner():SendLua('notification.AddLegacy("Unsupported material shader!", NOTIFY_ERROR, 3)') return end
        if not IsValid(self.TargetEntity) then self:GetOwner():SendLua('notification.AddLegacy("No target entity!", NOTIFY_ERROR, 3)') return end

        local maxpaints = GetConVar("superpaint_maxpaints"):GetInt()
        if not self:GetOwner():IsSuperAdmin() and self.TargetEntity.superpaints and #self.TargetEntity.superpaints >= maxpaints then 
            self:GetOwner():SendLua( 'notification.AddLegacy("Cannot paint more decals on this prop!", NOTIFY_ERROR, 3) EmitSound("superpaintfart.mp3", vector_origin, -2, CHAN_STATIC)' )
            return
        end

        local w, h = self:GetClientNumber("width"), self:GetClientNumber("height")
        DoSuperPaint(self.TargetEntity, self:GetClientInfo("mat"), self.TargetEntity:WorldToLocal(trace.StartPos), self.TargetEntity:WorldToLocal(trace.HitPos), w, h)
        EmitSound("superpaintsploink.mp3", trace.HitPos, 0, CHAN_STATIC, 1, 100, SND_NOFLAGS, math.Remap(w, 0.01, 128, 150, 70))
    end
end

function TOOL:RightClick( trace )
    if CLIENT then return end
    if trace.HitSky or not IsValid(trace.Entity) then self:GetOwner():SendLua('notification.AddLegacy("Tried to select invalid target entity!", NOTIFY_ERROR, 3)') return end
    if not self:GetOwner():IsSuperAdmin() and trace.Entity:GetOwner() ~= self:GetOwner() then return self:GetOwner():SendLua('notification.AddLegacy("You do not own this entity!", NOTIFY_ERROR, 3)') end
    self.TargetEntity = trace.Entity
    self:GetOwner():SendLua("LocalPlayer():GetTool('superpaint').TargetEntity = Entity("..self.TargetEntity:EntIndex()..")")
    self:ResetGhostEnt()

    return true
end

function TOOL:DrawHUD()
    if IsValid(self.TargetEntity) then
        if IsValid(self.GhostEnt) then
            self.GhostEnt:SetPos(self.TargetEntity:GetPos())
            self.GhostEnt:SetAngles(self.TargetEntity:GetAngles())
            local tr = LocalPlayer():GetEyeTrace()
            cam.Start3D()
            util.DecalEx(self.PreviewMat, self.GhostEnt, tr.HitPos, tr.HitNormal, color_white, self:GetClientNumber("width"), self:GetClientNumber("height"))
            render.SetBlend(0.3)
            self.GhostEnt:DrawModel()
            self.GhostEnt:RemoveAllDecals()
            render.SetBlend(1)
            cam.End3D()
        else
            self.GhostEnt = ClientsideModel(self.TargetEntity:GetModel())
            self.GhostEnt:SetMaterial(self.TargetEntity:GetMaterial())
            self.GhostEnt:SetModelScale(self.TargetEntity:GetModelScale())
            self.GhostEnt:SetNoDraw(true)
        end
    else
        if self.GhostEnt then
            self.GhostEnt:Remove()
        end
    end
end

function TOOL:ResetGhostEnt()
    self:GetOwner():SendLua( "if not LocalPlayer():GetTool() then return end local lt = LocalPlayer():GetTool('superpaint') if IsValid(lt.GhostEnt) then lt.GhostEnt:Remove() end" )
end

function TOOL:Holster()
    if CLIENT then return end
    self:ResetGhostEnt()
end

function TOOL:Reload()
    if self:GetOwner():KeyDown(IN_USE) then
        self.TargetEntity = nil
        self:GetOwner():SendLua("LocalPlayer():GetTool('superpaint').TargetEntity = nil")
        return
    end

    local ent = self.TargetEntity
    if not IsValid(self.TargetEntity) then return end

    if SERVER then
        ent.superpaints = nil
        duplicator.ClearEntityModifier(ent, "superpaintsave")
        ent:RemoveAllDecals()
    else
        ent:RemoveAllDecals()
    end

    return true
end

if CLIENT then
    TOOL.Information = {

		{ name = "info", stage = 1 },
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" },
        { name = "reload_use" }

	}

    language.Add("tool.superpaint.name", "Super Paint Tool")
	language.Add("tool.superpaint.desc", "Paint any material on an entity")
	language.Add("tool.superpaint.left", "Paint on target entity")
	language.Add("tool.superpaint.right", "Set target entity")
	language.Add("tool.superpaint.reload", "Remove all superpaints from target entity")
    language.Add("tool.superpaint.mat", "Material")
    language.Add("tool.superpaint.width", "Width Scale")
    language.Add("tool.superpaint.height", "Height Scale")
    language.Add("tool.superpaint.reload_use", "Unselect target entity")

    function TOOL.BuildCPanel( panel )
        panel:Help("Options")
		panel:TextEntry( "#tool.superpaint.mat", "superpaint_mat" )
		panel:NumSlider( "#tool.superpaint.width", "superpaint_width", 0.01, 128, 2 )
        panel:NumSlider( "#tool.superpaint.height", "superpaint_height", 0.01, 128, 2 )
        local swap = panel:Button("Swap Width and Height")
        function swap:DoClick()
            local oldw, oldh = GetConVar("superpaint_width"):GetFloat(), GetConVar("superpaint_height"):GetFloat()
            RunConsoleCommand("superpaint_width", oldh)
            RunConsoleCommand("superpaint_height", oldw)
        end

        panel:Help("Material Lists")
        panel:ControlHelp("Lists for unmounted games will not show")

        local matSelecter
        local filter
        local matLists = {generic = {}}

        local foundMats, gameDirs = file.Find("materials/superpaintconverted/*", "GAME")
        for _, name in pairs(foundMats) do table.insert(matLists.generic, "superpaintconverted/"..name) end

        local genbutton = panel:Button("Generic")
        function genbutton:DoClick()
            matSelecter:Clear()
            for k, v in pairs(matLists.generic) do
                matSelecter:AddMaterial(k, v)
            end

            if filter:GetValue() ~= "" then
                filter:OnValueChange(filter:GetValue())
            end
        end

        local niceTitles = {
            cstrike = "Counter-Strike: Source",
            ep2 = "Half-Life 2: Episode 2",
            episodic = "Half-Life 2: Episode 1",
            left4dead2 = "Left 4 Dead 2",
            tf = "Team Fortress 2",
            dods = "Day of Defeat: Source"
        }

        for _, gameDir in pairs(gameDirs) do
            if not IsMounted(gameDir) then continue end

            local but = panel:Button(niceTitles[gameDir] or gameDir)
            function but:DoClick()
                matSelecter:Clear()
                for k, v in pairs(matLists[gameDir]) do
                    matSelecter:AddMaterial(k, v)
                end

                if filter:GetValue() ~= "" then
                    filter:OnValueChange(filter:GetValue())
                end
            end

            local foundGameMats = file.Find("materials/superpaintconverted/"..gameDir.."/*.vmt", "GAME")
            matLists[gameDir] = {}

            for _, name in pairs(foundGameMats) do table.insert(matLists[gameDir], "superpaintconverted/"..gameDir.."/"..name) end
        end

        filter = panel:TextEntry("Quick Filter")
        filter:SetUpdateOnType( true )
        matSelecter = panel:MatSelect("superpaint_mat", matLists.generic, true, 0.25, 0.25)

        filter.OnValueChange = function( s, txt )
            for id, pnl in ipairs( matSelecter.Controls ) do
                if ( !pnl.Value:lower():find( txt:lower(), nil, true ) ) then
                    pnl:SetVisible( false )
                else
                    pnl:SetVisible( true )
                end
            end
            matSelecter:InvalidateChildren()
        end
	end
end