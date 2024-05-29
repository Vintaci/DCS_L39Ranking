--[[
    TODO: 将速度, 航向, 高度, 升降率, 滚转率检查单独放在Monitior检查, 状态变更只进行状态过渡和需要检查数据的变更

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

        obj.onCourse = false
        obj.onCenterLine = false
        obj.onAltitude = false
        obj.onSpeed = false

        obj.crosswindLegHeading = nil
        obj.downwindLegHeading = nil

        obj.takeOffPoint = nil

        obj.points = {
            radio = 5,
            taxi = 5,
            takeOff = 5,
            course = 5,
            attitude = 5,
            approch = 5,
            landing = 5,
        }

        obj.penalties = {}

        obj.MonitorID = nil

        setmetatable(obj,self)
        self.__index = self

        return 
    end

    function PlayerMonitor:remove()
        if self.MonitorID then
            self:stop()
        end

        PlayerMonitor.allGroups[self.groupName] = nil
    end

    function PlayerMonitor._MonitorFunc(vars,time)
        local self = vars.context
        local repeatTime = vars.repeatTime
        
        if not self:validation() then
            self:remove()
            return nil
        end

        local unit = self.unit
        local unitPoint = unit:getPoint()
        --转换到滑行阶段
        if mist.pointInPolygon(unitPoint,Config.TaxiWays.TaxiWay) then
            local AGL = unitPoint.y
            if AGL <= Config.Data.L39C.landAlt then

                Utils.messageToAll('Enter Taxi') --Debug

                self.stage = PlayerMonitor.Stage.Taxing
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
                        return time+repeatTime
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

                状态转换: 进入滑行道范围转为滑行状态
            ]]

            --转换到短停阶段
            if mist.pointInPolygon(unitPoint,Config.RunWay[self.ActiveRunWay].entrance.HoldShort) then
                local AGL = unitPoint.y
                local Speed = math.floor(mist.utils.converter('mps','kmph',mist.vec.mag(unit:getVelocity())))
                if AGL <= Config.Data.L39C.landAlt and Speed <= 10 then

                    Utils.messageToAll('Enter HoldShort') --Debug

                    self.stage = PlayerMonitor.Stage.HoldShort
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

                状态转换: 进入滑行道范围转为滑行状态
            ]]
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
                3.起飞松杆出现掉高扣 3 分
                4.起飞出现反复接地扣 5 分

                状态转换: 进入滑行道范围转为滑行状态
            ]]
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
                2.起飞、着陆未放襟翼扣 3 分

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



        return time+repeatTime
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