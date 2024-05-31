--[[
    DONE: 将航向, 升降率, 滚转, 俯仰, 对齐中线检查单独放在Monitior检查, 状态变更只进行状态过渡和需要特殊检查数据的变更

    TODO: 一边到五边的飞行数据检查和状态转换
    TODO: 训练模式下的提示
    TODO: 接地后输出成绩
    TODO: 添加音频

]]

PlayerMonitor = {}
do
    local ev = {}

    function ev:onEvent(event)
        if event.id == world.event.S_EVENT_BIRTH and event.initiator and event.initiator.getPlayerName then
            if event.initiator:getTypeName() == 'L-39C' then
                local unit = event.initiator
                PlayerMonitor:new(unit)
            end     
        end
    end

    world.addEventHandler(ev)

    PlayerMonitor.MonitorRepeatTime = Config.PlayerMonitor.MonitorRepeatTime

    PlayerMonitor.Stage = {
        BeforeTaxi = 'BeforeTaxi',
        Taxing = 'Taxing',
        HoldShort = 'HoldShort',
        BeforeTakeOff = 'BeforeTakeOff',
        Rolling = 'Rolling',
        Climb = 'Climb',
        UpwindLeg = 'UpwindLeg', --一边
        CrosswindLeg = 'CrosswindLeg', --二边
        DownwindLeg = 'DownwindLeg', --三边
        BaseLeg = 'BaseLeg', --四边
        FinalApproach = 'FinalApproach', --五边
        Landing = 'Landing',
        AfterTouchDown = 'AfterTouchDown'
    }

    PlayerMonitor.allGroups = {}

    function PlayerMonitor:new(unit)
        if not unit then return end

        local group = unit:getGroup()
        if not group then return end

        local groupName = group:getName()
        if not groupName then return end

        if PlayerMonitor.allGroups[groupName] then
            PlayerMonitor.allGroups[groupName]:remove()
        end

        local obj = {}

        obj.group = group
        obj.unit = unit
        obj.groupName = groupName
        obj.type = unit:getTypeName()

        obj.stage = PlayerMonitor.Stage.BeforeTaxi
        obj.assignedRunway = Config.ActiveRunWay or '09'

        local checkLists = Config.checkLists[obj.type]
        obj.BeforeTaxiCheckList = checkLists.BeforeTaxiCheckList or {finish = true}
        obj.BeforeTakeOffCheckList = checkLists.BeforeTakeOffCheckList or {finish = true}
        obj.BeforeLandingCheckList = checkLists.BeforeLandingCheckList or {finish = true}

        obj.pitchUpLimit = nil
        obj.headingLimit = nil
        obj.climbRateLimit = nil
        obj.decentRateLimit = nil
        obj.rollLimit = nil
        obj.centerLine = nil
        
        obj.onAltitude = false
        obj.onSpeed = false

        obj.onCourse = false
        obj.onCenterLine = false
        obj.onPitch = false
        obj.onRoll = false
        obj.onClimbRate = false

        obj.flaps = false
        obj.landingGear = false
        obj.lights = false

        obj.crosswindLegHeading = nil
        obj.downwindLegHeading = nil

        obj.takeOffPoint = nil

        obj.points = {
            radio = 5,
            taxi = 5,
            takeOff = 5,
            cruise = 5,
            attitude = 5,
            approch = 5,
            landing = 5,
        }

        obj.penalties = {}

        obj.MonitorID = nil
        obj.repeatTime = PlayerMonitor.MonitorRepeatTime

        setmetatable(obj,self)
        self.__index = self

        local ev = {}
        ev.context = self

        function ev:onEvent(event)
            if event.id == world.event.S_EVENT_TAKEOFF and event.initiator and event.initiator.getPlayerName then
                local unit = event.initiator
                if not unit then return end

                local group = unit:getGroup()
                if not group then return end

                local groupName = group:getName()
                if not groupName then return end    

                PlayerMonitor.allPlayers[groupName].takeOffPoint = unit:getPoint()
                PlayerMonitor.allPlayers[groupName].stage = PlayerMonitor.Stage.Climb
            end

            if event.id == world.event.S_EVENT_LAND and event.initiator and event.initiator.getPlayerName then
                
            end
        end
        world.addEventHandler(ev)

        PlayerMonitor.allGroups[groupName] = obj
        obj:start()
        return obj
    end

    function PlayerMonitor:remove()
        if self.MonitorID then
            self:stop()
        end

        PlayerMonitor.allGroups[self.groupName] = nil
    end

    function PlayerMonitor:setStandards(vars)
        self.headingLimit = vars.heading or nil
        self.pitchUpLimit = vars.pitchUpLimit or nil
        self.climbRateLimit = vars.climbRate or nil
        self.decentRateLimit = vars.decent or nil
        self.rollLimit = vars.roll or nil
        self.centerLine = vars.centerLine or nil

        if vars.heading then
            self.onCourse = false
        end
        if vars.pitchUpLimit then
            self.onPitch = false
        end
        if vars.climbRate or vars.decent then
            self.onClimbRate = false
        end
        if vars.roll then
            self.onRoll = false
        end
        if vars.centerLine then
            self.onCenterLine = false
        end
    end

    function PlayerMonitor.isIntersect(myLine_Start, myLine_End, otherLine_Start, otherLine_End)
        local function ccw(A, B, C)
            return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x)
        end
    
        local function intersect(A, B, C, D)
            return ccw(A, C, D) ~= ccw(B, C, D) and ccw(A, B, C) ~= ccw(A, B, D)
        end
    
        return intersect(myLine_Start, myLine_End, otherLine_Start, otherLine_End)
    end

    function PlayerMonitor.checkLineup(unit,unitPoint,heading,centerLine)
        if not unit or not unit.getTypeName then return false end
        if not centerLine then return false end
        
        local lines = centerLine.line

        local LeftWheelPos = Utils.vecTranslate(unitPoint,heading-90,mist.utils.feetToMeters(Config.Data[self.type].LeftWheel))
        local RightWheelPos = Utils.vecTranslate(unitPoint,heading+90,mist.utils.feetToMeters(Config.Data[self.type].RightWheel))
        
        for i=1,#lines-1 do
            local centerLine_Start = lines[i]
            local centerLine_end = lines[i+1]

            if PlayerMonitor.isIntersect(LeftWheelPos, RightWheelPos, centerLine_Start, centerLine_end) then return true end
        end

        return false
    end

    function PlayerMonitor:validation()
        local unit = self.unit
        if not unit or unit:getLife() < 1 then return false end

        local group = self.group
        if not group or not group:getUnit(1) then return false end

        return true
    end

    function PlayerMonitor:PerformCheckList(checkList,unit)
        if checkList.finish then return true end
        if not unit or not unit:isExist() or not unit.getDrawArgumentValue then return false end

        local unitID = unit:getID()

        local allDone = true
        for itemId,item in ipairs(checkList) do
            if not item.check then
                allDone = false
                if not item.notice then
                    local msg = item.text
                    trigger.action.outTextForUnit(unitID,msg,10)
                    item.notice = true
                end
                
                item.func(self,unit,itemId)
                
                if item.check then
                    local msg = item.text..': 检查.'
                    trigger.action.outTextForUnit(unitID,msg,10)
                end

                return allDone
            end
        end

        if allDone then
            checkList.finish = true
        end
        return allDone
    end

    function PlayerMonitor._MonitorFunc(vars,time)
        local self = vars.context
        
        if not self:validation() then
            self:remove()
            return nil
        end

        local unit = self.unit
        local unitPoint = unit:getPoint()

        
        self.penalties = self.penalties or {}
        self.penalties[self.stage] = self.penalties[self.stage] or {}
        local tableSize = Utils.getTbaleSize(self.penalties[self.stage])
        local lastUpdateTime = timer.getTime()-10
        if tableSize > 0 then
            lastUpdateTime = self.penalties[self.stage].lastUpdateTime
        end

        if self.centerLine then

            local unitPosition = unit:getPosition()
            local Heading = math.atan2(unitPosition.x.z, unitPosition.x.x)
            if Heading < 0 then
                Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
            end

            if not self.onCenterLine then
                if PlayerMonitor.checkLineup(unit,unitPoint,Heading,self.centerLine) then
                    self.onCenterLine = true

                    --Other Logic
                end
            end

            if self.onCenterLine then
                if not PlayerMonitor.checkLineup(unit,unitPoint,Heading,self.centerLine) then
                    self.onCenterLine = false

                    --Add penalties
                    self.penalties[self.stage]['lineUp'] = self.penalties[self.stage]['lineUp'] or {}

                    if timer.getTime() - lastUpdateTime >= 10 then
                        local newPenalty = {
                            reason = '滑行、滑跑未压中线或偏离',
                            point = 1,
                            time = timer.getTime()
                        }

                        table.insert(self.penalties[self.stage]['lineUp'],newPenalty)
                        self.penalties[self.stage].lastUpdateTime = timer.getTime()
                    end
                end
            end

        end

        if self.headingLimit then
            local unitPosition = unit:getPosition()
            local Heading = math.atan2(unitPosition.x.z, unitPosition.x.x)
            if Heading < 0 then
                Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
            end

            if not self.onCourse then
                if math.abs(Heading - self.headingLimit) <= 3 then
                    self.onCourse = true

                    --Other Logic
                end
            end

            if self.onCourse then
                if math.abs(Heading - self.headingLimit) > 3 then
                    self.onCourse = false

                    --Add penalties
                    self.penalties[self.stage]['heading'] = self.penalties[self.stage]['heading'] or {}

                    if timer.getTime() - lastUpdateTime >= 10 then
                        local newPenalty = {
                            reason ='滑行、滑跑未压中线或偏离',
                            point = 1,
                            time = timer.getTime()
                        }
                        if math.abs(Heading - self.headingLimit) > 5 then
                            newPenalty.point = 2
                        end

                        table.insert(self.penalties[self.stage]['heading'],newPenalty)
                        self.penalties[self.stage].lastUpdateTime = timer.getTime()
                    end
                end
            end

        end

        if self.climbRateLimit then
            
            local velocity = unit:getVelocity()
            local climbRate = velocity.y
            if not self.onClimbRate then
                if climbRate < self.climbRateLimit then
                    self.onClimbRate = true

                    --Other Logic
                end
            end

            if self.onClimbRate then
                if climbRate > self.climbRateLimit then
                    self.onClimbRate = false

                    --Add penalties
                    self.penalties[self.stage]['climb'] = self.penalties[self.stage]['climb'] or {}

                    local gearUp = false
                    if unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_L) <= 0.85 or 
                       unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_R) <= 0.85 or 
                       unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_N) <= 0.85 
                    then
                        gearUp = true
                    end

                    if not gearUp then
                        if climbRate < 0 then
                            if timer.getTime() - lastUpdateTime >= 10 then
                                local newPenalty = {
                                    reason ='起飞松杆出现掉高',
                                    point = 3,
                                    time = timer.getTime()
                                }
    
                                table.insert(self.penalties[self.stage]['climb'],newPenalty)
                                self.penalties[self.stage].lastUpdateTime = timer.getTime()
                            end
                        end
                    end

                    if gearUp then
                        if climbRate < -5 then
                            if timer.getTime() - lastUpdateTime >= 10 then
                                local newPenalty = {
                                    reason ='爬升中垂直速率为负',
                                    point = 35,
                                    time = timer.getTime()
                                }

                                table.insert(self.penalties[self.stage]['climb'],newPenalty)
                                self.penalties[self.stage].lastUpdateTime = timer.getTime()
                            end
                        end
                    end
                end
            end

        end

        if self.decentRateLimit then
            
            local velocity = unit:getVelocity()
            local climbRate = velocity.y
            if not self.onClimbRate then
                if climbRate > self.decentRateLimit then
                    self.onClimbRate = true

                    --Other Logic
                end
            end

            if self.onClimbRate then
                if climbRate < self.climbRateLimit then
                    self.onClimbRate = false

                    --Add penalties
                    if climbRate > 5 then
                        self.penalties[self.stage]['decent'] = self.penalties[self.stage]['decent'] or {}

                        if Utils.getTbaleSize(self.penalties[self.stage]['decent']) <= 0  then
                            local newPenalty = {
                                reason ='下高出现上升',
                                point = 35,
                                time = timer.getTime()
                            }

                            table.insert(self.penalties[self.stage]['decent'],newPenalty)
                            self.penalties[self.stage].lastUpdateTime = timer.getTime()
                        end
                    end
                end
            end

        end

        if self.pitchUpLimit then

            local unitpos = unit:getPosition()
            local Pitch = math.asin(unitpos.x.y)
            if not self.onPitch then
                if Pitch < self.pitchUpLimit then
                    self.onPitch = true

                    --Other Logic
                end
            end

            if self.onPitch then
                if Pitch > self.pitchUpLimit then
                    self.onPitch = false

                    --Other Logic
                end
            end

        end

        if self.rollLimit then

            local unitpos = unit:getPosition()
            local cp = mist.vec.cp(unitpos.x, {x = 0, y = 1, z = 0})
            local dp = mist.vec.dp(cp, unitpos.z)
            local Roll = math.acos(dp/(mist.vec.mag(cp)*mist.vec.mag(unitpos.z)))

            if not self.onRoll then
                if Roll < self.rollLimit then
                    self.onRoll = true

                    --Other Logic
                end
            end

            if self.onRoll then
                if Roll > self.rollLimit then
                    self.onRoll = false

                    --Other Logic
                end
            end

        end
        
        --转换到滑行阶段
        if mist.pointInPolygon(unitPoint,Config.TaxiWays.TaxiWay) then
            local AGL = unitPoint.y - land.getHeight({x = unitPoint.x,y = unitPoint.z})
            if AGL <= Config.Data[self.type].landAlt then

                Utils.messageToAll('Enter Taxi') --Debug

                self.stage = PlayerMonitor.Stage.Taxing

                local speedMax = 60
                if mist.pointInPolygon(unitPoint,Config.TaxiWays.TaxiWay_Turn) then
                    speedMax = 20
                end

                self:setStandards({centerLine = Config.TaxiWays.TaxiWay_Center})
            end
        end

        if self.stage == PlayerMonitor.Stage.BeforeTaxi then
            --[[
                要求:
                1.滑行前检查单: 设置RMI航向,襟翼,滑行灯

                状态转换: 进入滑行道范围转为滑行状态
            ]]

            local Speed = math.floor(mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity())))
            if Speed <= 10 then
                if not self.BeforeTaxiCheckList.finish then

                    if not self:PerformCheckList(self.BeforeTaxiCheckList,unit) then
                        return time+1
                    end

                    if self.BeforeTaxiCheckList.finish then
                        local unitID = unit:getID()
                        local msg = self.BeforeTaxiCheckList.checkListName..', 完成.'
                        trigger.action.outTextForUnit(unitID,msg,10)
                    end

                end
            end
        end

        if self.stage == PlayerMonitor.Stage.Taxing then
            --[[
                要求:
                1.滑行过程中前鼻轮压白线,左右偏移不得超过主起落架间距一半
                2.直线滑行速度不高于 60 公里每小时,转向时速度不高于 20 公里每小时

                扣分:
                1.冲入草地、撞击树木为不及格
                2.滑行、滑跑未压中线或偏离扣 1 分
                3.滑行速度超限≤25%扣分 1 分，＜50%＞25%扣 2 分，≥50%扣 5 分
                4.滑行直线超过 60,转向超过 20 每次扣 1 分,三次扣 5 分.
                5.未正确使用灯光扣 1 分

                状态转换: 进入跑道范围转为起飞前准备状态
            ]]

            --转换到短停阶段
            if mist.pointInPolygon(unitPoint,Config.RunWay[self.ActiveRunWay].entrance.HoldShort) then
                local AGL = unitPoint.y
                local Speed = math.floor(mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity())))
                if AGL <= Config.Data[self.type].landAlt and Speed <= 10 then

                    Utils.messageToAll('Enter HoldShort') --Debug

                    self.stage = PlayerMonitor.Stage.HoldShort
                    return time+self.repeatTime
                end
            end

            --转换进入跑道
            if mist.pointInPolygon(unitPoint,Config.RunWay.RunwayPolygon) then

                Utils.messageToAll('Enter BeforeTakeOff') --Debug
                self.stage = PlayerMonitor.Stage.BeforeTakeOff

                self:setStandards({centerLine = Config.RunWay.Runway_Center})
                return time+self.repeatTime
            end

            local speedLimit = 60
            --进入滑行道转向区域
            if mist.pointInPolygon(unitPoint,Config.TaxiWays.TaxiWay_Turn) then
                speedLimit = 20
            end

            self.penalties = self.penalties or {}
            self.penalties[self.stage] = self.penalties[self.stage] or {}

            local tableSize = Utils.getTbaleSize(self.penalties[self.stage])
            local lastUpdateTime = timer.getTime()-10
            if tableSize > 0 then
                lastUpdateTime = self.penalties[self.stage].lastUpdateTime
            end

            if timer.getTime() - lastUpdateTime >= 10 then
                local speedKmph = mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity()))
                if not self.onSpeed then
                    if (speedKmph - speedLimit ) < speedLimit*(1+0.25) then
                        self.onSpeed = true

                        --Other Logic
                    end
                end

                if self.onSpeed then
                    if (speedKmph - speedLimit ) >= speedLimit*(1+0.25) then
                        self.onSpeed = false
                        
                        --Add penalties
                        self.penalties = self.penalties or {}
                        self.penalties[self.stage] = self.penalties[self.stage] or {}
                        self.penalties[self.stage]['speed'] = self.penalties[self.stage]['speed'] or {}

                        local newPenalty = {
                            reason = string.format('滑行速度超限≤25%(限速:%d km/h, 记录时: %d km/h)',speedLimit, math.floor(speedKmph)),
                            point = 1,
                            time = timer.getTime()
                        }

                        if (speedKmph - speedLimit ) >= speedLimit*(1+0.25) and (speedKmph - speedLimit ) <= speedLimit*(1+0.5) then
                            newPenalty.reason = string.format('滑行速度超限25%~50%(限速:%d km/h, 记录时: %d km/h)',speedLimit, math.floor(speedKmph))
                            newPenalty.point = 2
                        end

                        if (speedKmph - speedLimit ) >= speedLimit*(1+0.5) then
                            newPenalty.reason = string.format('滑行速度超限≥50%(限速:%d km/h, 记录时: %d km/h)',speedLimit, math.floor(speedKmph))
                            newPenalty.point = 5
                        end

                        table.insert(self.penalties[self.stage]['speed'],newPenalty)
                        self.penalties[self.stage].lastUpdateTime = timer.getTime()
                    end
                end
                
                self.penalties[self.stage]['lights'] = self.penalties[self.stage]['lights'] or {}
                if Utils.getTbaleSize(self.penalties[self.stage]['lights']) <= 0 then
                    if unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.TaxiLightID) <= 0 then
                        local newPenalty = {
                            reason = '未正确使用灯光',
                            point = 1,
                            time = timer.getTime()
                        }

                        table.insert(self.penalties[self.stage]['lights'],newPenalty)
                        self.penalties[self.stage].lastUpdateTime = timer.getTime()
                    end
                end
            end
        end

        if self.stage == PlayerMonitor.Stage.HoldShort then
            --[[
                要求:
                1.起飞前检查单: 襟翼,着陆灯
                2.进入跑道需迅速,严禁在跑道上做检查工作,严禁长时间占用跑道.
                

                状态转换: 进入滑行道范围转为滑行状态
            ]]
            local Speed = math.floor(mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity())))
            if Speed <= 10 then
                if not self.BeforeTakeOffCheckList.finish then

                    if not self:PerformCheckList(self.BeforeTakeOffCheckList,unit) then
                        return time+1
                    end

                    if self.BeforeTakeOffCheckList.finish then
                        local unitID = unit:getID()
                        local msg = self.BeforeTakeOffCheckList.checkListName..', 完成.'
                        trigger.action.outTextForUnit(unitID,msg,10)
                    end

                end
            end
        end

        if self.stage == PlayerMonitor.Stage.BeforeTakeOff then
            --到滑跑阶段
            local Speed = mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity()))
            if Speed > 60 then
                Utils.messageToAll('Enter Rolling') --Debug
                self.stage = PlayerMonitor.Stage.Rolling

                self:setStandards({pitchUpLimit = 10,climbRate = 8,centerLine = Config.RunWay.Runway_Center})
                return time+self.repeatTime
            end
        end

        if self.stage == PlayerMonitor.Stage.Rolling then
            --[[
                要求:
                1.压中线起飞
                2.建立 10°以内仰角姿态

                扣分:
                1.滑行、滑跑未压中线或偏离扣 1 分
                2.滑跑迎角＜15°＞10°扣 1 分，＞15°扣 3 分
                3.起飞、着陆未放襟翼扣 3 分
                4.起飞、着陆擦尾扣 3 分
                5.未正确使用灯光扣 1 分

                状态转换: 离地建立正上升后转为爬升阶段
            ]]

            --到起飞爬升阶段
            local unitVelocity = unit:getVelocity()
            local ClimbRate = unitVelocity.y
            if ClimbRate > 0 then
                Utils.messageToAll('Enter Climb') --Debug
                self.stage = PlayerMonitor.Stage.Climb
                
                self.takeOffPoint = unitPoint
                self:setStandards({heading = Config.RunWay[self.ActiveRunWay].heading,climbRate = 8,pitchUpLimit = 10})
                return time+self.repeatTime
            end

            self.penalties = self.penalties or {}
            self.penalties[self.stage] = self.penalties[self.stage] or {}

            lastUpdateTime = self.penalties[self.stage].lastUpdateTime
            if not self.penalties[self.stage]['lights'] then
                if unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.TaxiLightID) <= 0 then
                    local newPenalty = {
                        reason = '未正确使用灯光',
                        point = 1,
                        time = timer.getTime()
                    }

                    table.insert(self.penalties[self.stage]['lights'],newPenalty)
                    self.penalties[self.stage].lastUpdateTime = timer.getTime()
                end
            end

            if timer.getTime() - lastUpdateTime >= 10 then
                if unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.Flap_L) <= 0 or unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.Flap_L) >= 0.9 then
                    local newPenalty = {
                        reason = '起飞、着陆未放襟翼',
                        point = 3,
                        time = timer.getTime()
                    }

                    table.insert(self.penalties[self.stage]['flaps'],newPenalty)
                    self.penalties[self.stage].lastUpdateTime = timer.getTime()
                end
            end
            
            if mist.vec.mag(unitVelocity) ~= 0 then
                if timer.getTime() - lastUpdateTime >= 10 then
                    local unitpos = unit:getPosition()
                    local AxialVel = {}	--unit velocity transformed into aircraft axes directions

                    --transform velocity components in direction of aircraft axes.
                    AxialVel.x = mist.vec.dp(unitpos.x, unitVelocity)
                    AxialVel.y = mist.vec.dp(unitpos.y, unitVelocity)
                    AxialVel.z = mist.vec.dp(unitpos.z, unitVelocity)

                    local AoA = math.acos(mist.vec.dp({x = 1, y = 0, z = 0}, {x = AxialVel.x, y = AxialVel.y, z = 0})/mist.vec.mag({x = AxialVel.x, y = AxialVel.y, z = 0}))
                    if AxialVel.y > 0 then
                        AoA = -AoA
                    end

                    if AoA > 10 then
                        local newPenalty = {
                            reason = '滑跑迎角 >10°',
                            point = 1,
                            time = timer.getTime()
                        }

                        if AoA > 15 then
                            newPenalty.reason = '滑跑迎角 >15°'
                            newPenalty.point = 1
                        end
                        
                        table.insert(self.penalties[self.stage]['AoA'],newPenalty)
                        self.penalties[self.stage].lastUpdateTime = timer.getTime()
                    end
                end
            end
        end

        if self.stage == PlayerMonitor.Stage.Climb then
            --[[
                要求:
                1.确认正上升率后收起落架.离地后严格注意杆量
                2.检查偏航情况及时修正保持跑道航向
                3.雷达高度 50 米收襟翼
                4.姿态稳定后告知 ATC 离地, 并做离地检查
                5.严禁出现任何掉高

                扣分:
                1.起飞偏航＞3° ＜5° 扣 1 分，＞5°扣 2 分
                2.起飞 100 米后未收起落架扣 1 分
                3.起飞松杆出现掉高扣 3 分(有待完善)
                4.起飞出现反复接地扣 5 分

                状态转换: 雷达高超过50M转为一边
            ]]

            --转为一边
            local AGl = unitPoint.y - land.getHeight({x = unitPoint.x,y = unitPoint.z})
            if AGl > 50 then
                Utils.messageToAll('Enter UpwindLeg') --Debug
                self.stage = PlayerMonitor.Stage.UpwindLeg
                
                self:setStandards({heading = Config.RunWay[self.ActiveRunWay].heading,climbRate = 8})
                return time+self.repeatTime
            end

            self.penalties = self.penalties or {}
            self.penalties[self.stage] = self.penalties[self.stage] or {}

            lastUpdateTime = self.penalties[self.stage].lastUpdateTime
            if self.takeOffPoint then
                if mist.utils.get2DDist(self.takeOffPoint,unitPoint) > 100 then  
                    if unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_L) > 0.85 or unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_R) > 0.85 or unit:getDrawArgumentValue(Config.Data[self.type].DrawArguementIDs.LandingGear_N) then
                        if timer.getTime() - lastUpdateTime >= 10 then
                            local newPenalty = {
                                reason = '起飞 100 米后未收起落架',
                                point = 1,
                                time = timer.getTime()
                            }

                            table.insert(self.penalties[self.stage]['landingGear'],newPenalty)
                            self.penalties[self.stage].lastUpdateTime = timer.getTime()
                        end
                    end
                end
            end

        end

        if self.stage == PlayerMonitor.Stage.UpwindLeg then
            --[[
                要求:
                1.爬升速率不得超过 8 米每秒(垂直速率表 4 格以内)
                2.严禁出现任何掉高
                3.增速至 400 公里后适当收油保持空速
                4.检查偏航情况及时修正保持跑道航向

                扣分:
                1.爬升中垂直速率为负数即判定不及格
                2.偏航＞3° ＜5° 扣 1 分，＞5°扣 2 分
                3.气压高度 450 后未转向扣 2 分
                4.一转坡度＞30°＜45°扣 1 分，≥45 扣 2 分

                状态转换: 待气压高度 400 米后进行一边至三边(267)转向.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.CrosswindLeg then
            --[[
                要求:
                1.最大坡度不超过30°, 建议保持每秒 3-5 度的坡度增加率
                2.严禁出现任何掉高
                3.增速至 400 公里后适当收油保持空速

                扣分:
                1.爬升中垂直速率为负数即判定不及格

                状态转换: 在三边航向前5-10°时提前减少坡度,最终航向为 267.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.DownwindLeg then
            --[[
                要求:
                1.保持航向 267,空速 400 公里,高度 600 米
                2.当 ADF 指针只是 NDB 远台位于相对航向 270 时开始减速,准备下高
                3.下高准备:保持航向,高度前提下,完全收空油门减速,不使用减速板,待空速低于 350 公里后放出起落架,
                  待空速低于 300 公里后适当增加油门保持270 公里空速,向 ATC 申请转向.
                4.减速过程中严禁出现掉高与偏航
                5.下高势能转换成成动能,严格控制空速不要超过 290 公里,防止襟翼自动收起

                扣分:
                1.巡航过程中空速≤380 扣 1 分，≥420 扣 1 分，≥450 扣 3 分，≤350 扣 3 分
                2.巡航过程中偏航≤3°扣 1 分，≥5°扣 2 分
                3.巡航程中高度偏差≤580 扣 1 分，c620 扣 1 分，≥650 扣 3 分，≥550 扣 3 分
                4.昼间 NDB 过 250 未减速扣 2 分，夜间 NDB 过 220 未减速扣 2 分(ATC 要求保持三边除外)
                5.二转未放襟翼扣 3 分

                状态转换: 获得许可后放出起飞襟翼,开始转向,飞航向177,空速保持250-270 公里.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.BaseLeg then
            --[[
                要求:
                1.航向保持 177
                2.RSBN 距离指示器 10 公里前最低下降高度不得低于气压高度 300 米
                3.需在距离指示器 7 公里前对正跑道中线延长线即航向道.与跑道的横向误差要控制在跑道的宽度内(40 米)

                扣分:
                1. 7公里未对正航向道扣 3 分

                状态转换: 获得许可后放出起飞襟翼,开始转向,飞航向177,空速保持250-270 公里.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.FinalApproach then
            --[[
                要求:
                1.远台前减速至 220 公里
                2.整个进近至接地前,空速严禁低于 200 高于 250()
                3.飞跃远台正上方时,距离指示器为 5,雷达高度 170 米,此时放出着陆襟翼
                4.飞跃近台时距离显示为 1,高度 70 米,进入跑道是高度为 15 米.
                5.标准下滑角为三度
                6.高度正确前提下下降率为4 米秒左右
                7.除非复飞,严禁出现上升.

                扣分:
                1.远台前气压高度低于 200 米为不及格
                2.进近未放起落架为不及格
                3.进近速度≥300 扣 3 分 ≤200 扣 3 分
                4.远台高于 230 米扣 2 分，低于 120 米扣 2 分
                5.近台高于 110 米扣 2 分，低于 40 米扣 2 分

                状态转换: 获得许可后放出起飞襟翼,开始转向,飞航向177,空速保持250-270 公里.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.Landing then
            --[[
                要求:
                1.迎角不超过12°
                2.着陆需在着陆区
                3.接地时,前鼻轮需在跑道中线附近,且在主起落架间距内.
                4.严禁出现擦尾 弹跳 拉飘
                5.滑行减速需保持在中线上
                6.高度正确前提下下降率为4 米秒左右
                7.除非复飞,严禁出现上升.

                扣分:
                1.着陆超出接地区扣 3 分
                2.着陆弹跳扣 3 分
                3.拉飘酌情扣 1-3 分
                4.起飞、着陆擦尾扣 3 分

                状态转换: 获得许可后放出起飞襟翼,开始转向,飞航向177,空速保持250-270 公里.
            ]]
        end

        if self.stage == PlayerMonitor.Stage.AfterTouchDown then
            --[[
                滑回或触地复飞:接地后根据飞行计划,告知 ATC 已接地或进行触地复飞,
                若为滑回,复述ATC滑行指令,在正确道口脱离跑道.若为触地复飞,应当在
                接地同时推满油门,在离地后告知 ATC 已离地等候指令.
                注意:脱离跑道前需充分减速,转向和直线滑行速度同上.

                扣分:
                1.错过指定联络道扣 1 分

                复飞操作:
                1.立即油门最大位
                2.立即中止下降,空速允许下爬升或,如果较低空速就平飞
                3.立即收起落架,空速 200 以上时建立爬升,并维持 8 米秒以上爬升率
                4.保持跑道航向
                5.姿态稳定后联系 ATC 告知已复飞听从指示
            ]]
        end

        return time+self.repeatTime
    end

    function PlayerMonitor:start(Delay,RepeatScanSeconds)
        local tDelay = Delay or 1
        local RepeatScanInterval = RepeatScanSeconds or PlayerMonitor.MonitorRepeatTime

        if self.MonitorID then
            self:stop()
        end

        self.MonitorID = timer.scheduleFunction(self._MonitorFunc,{context = self,repeatTime = RepeatScanInterval},timer.getTime() + tDelay)
    end
    
    function PlayerMonitor:stop()
        if not self.MonitorID then return end
        timer.removeFunction(self.MonitorID)
        self.MonitorID = nil
    end
end