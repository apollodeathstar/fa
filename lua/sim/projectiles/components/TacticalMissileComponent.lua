--******************************************************************************************************
--** Copyright (c) 2023  clyf
--**
--** Permission is hereby granted, free of charge, to any person obtaining a copy
--** of this software and associated documentation files (the "Software"), to deal
--** in the Software without restriction, including without limitation the rights
--** to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--** copies of the Software, and to permit persons to whom the Software is
--** furnished to do so, subject to the following conditions:
--**
--** The above copyright notice and this permission notice shall be included in all
--** copies or substantial portions of the Software.
--**
--** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--** SOFTWARE.
--******************************************************************************************************

local SemiBallisticComponent = import("/lua/sim/projectiles/components/semiballisticcomponent.lua").SemiBallisticComponent

---@class TacticalMissileComponent : SemiBallisticComponent
TacticalMissileComponent = ClassSimple(SemiBallisticComponent) {

    ---@param self TacticalMissileComponent | Projectile
    MovementThread = function(self, skipLaunchSequence)
        local blueprintPhysics = self.Blueprint.Physics

        -- are we a wiggler?
        local zigZagger = false
        if blueprintPhysics.MaxZigZag and
            blueprintPhysics.MaxZigZag > self.MaxZigZagThreshold then
            zigZagger = true
        end

        if not skipLaunchSequence then
            -- launch
            local launchTurnRateRange = self.LaunchTurnRateRange
            local launchTurnRate = self.LaunchTurnRate + launchTurnRateRange * (2 * Random() - 1)
            self:SetTurnRate(launchTurnRate)

            local launchTicksRange = self.LaunchTicksRange
            local launchTicks = self.LaunchTicks + Random(-launchTicksRange, launchTicksRange)
            WaitTicks(launchTicks)

            -- boost
            local boostTurnRate, boostTime = self:TurnRateFromAngleAndHeight()
            if boostTime < 0 then
                boostTime = 0
            end

            self:SetTurnRate(boostTurnRate)
            WaitTicks(boostTime * 10 + 1)
        end

        -- glide
        local glideTurnRate, glideTime = self:TurnRateFromDistance()

        self:SetLifetime((glideTime + 3))

        -- try to create a smooth transition for zig-zaggers
        if zigZagger then
            if glideTime > 4.0 then
                for k = 1, 10 do
                    WaitTicks(4)
                    self:SetTurnRate(5 * k)
                end
                glideTime = glideTime - 4.0
            elseif glideTime > 2.0 then
                for k = 1, 5 do
                    WaitTicks(4)
                    self:SetTurnRate(10 * k)
                end
                glideTime = glideTime - 2.0
            elseif glideTime > 1.0 then
                for k = 1, 5 do
                    WaitTicks(2)
                    self:SetTurnRate(10 * k)
                end
                glideTime = glideTime - 1.0
            else
                self:SetTurnRate(50)
            end
        else
            self:SetTurnRate(glideTurnRate)
        end

        -- reduce the maximum zig zag frequency halfway so that they're unlikely to miss targets
        WaitTicks((0.75 * glideTime + 0.1) * 10)
        self:ChangeMaxZigZag(0.5)

        -- wait until we've allegedly hit our target
        WaitTicks((0.25 * glideTime + 1) * 10)

        -- then, if we still exist, we just want to stop existing. Therefore we find our way to the ground
        -- target the ground below us slowly turn towards the ground so that we do not fly off indefinitely
        local position = self:GetPosition()
        position[2] = GetSurfaceHeight(position[1], position[3])
        self:SetNewTargetGround(position)

        -- increase turn rate to aim towards the ground
        for k = 4, 1, -1 do
            self:SetTurnRate(10 * k)
            WaitTicks(6)
        end
    end,
}
