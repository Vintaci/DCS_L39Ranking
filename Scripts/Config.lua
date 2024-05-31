Config = {}

do
    Config.PlayerMonitor = {}
    Config.PlayerMonitor.MonitorRepeatTime = 2

    Config.TaxiWays = {
        ['AlphaTaxiWay'] = {
            Polygon = mist.getGroupPoints('AlphaTaxiPolygon-1'),
            HoldShort = mist.getGroupPoints('AlphaTaxiHoldShortPolygon-1'),
        },
        ['BetaTaxiWay'] = {
            Polygon = mist.getGroupPoints('BetaTaxiPolygon-1'),
            HoldShort = mist.getGroupPoints('AlphaTaxiHoldShortPolygon-1'),
        },
        ['CharleyTaxiWay'] = {
            Polygon = mist.getGroupPoints('CharleyTaxiPolygon-1'),
            HoldShort = mist.getGroupPoints('AlphaTaxiHoldShortPolygon-1'),
        },
        TaxiWay = mist.getGroupPoints('TaxiPolygon-1'),
        TaxiWay_Turn = mist.getGroupPoints('TaxiTurnPolygon-1'),
        TaxiWay_Center = {
            line = mist.getGroupPoints('TaxiCenterLine-1'),
            width = 0.762,
        },
    }

    Config.RunWay = {
        ['09'] = {
            heading = 87,
            NBD_Far = {
                x = 11411,
                y = 26,
                z = 362701,
            },
            NBD_Near = {
                x = 11568,
                y = 25,
                z = 365697,
            },
            entrance = Config.TaxiWays.AlphaTaxiWay,
            exit = Config.TaxiWays.CharleyTaxiWay,
        },
        ['27'] = {
            heading = 87,
            NBD_Far = {
                x = 11981,
                y = 32,
                z = 373614,
            },
            NBD_Near = {
                x = 11804,
                y = 29,
                z = 370241,
            },
            entrance = Config.TaxiWays.CharleyTaxiWay,
            exit = Config.TaxiWays.AlphaTaxiWay,
        },
        RunwayPolygon = mist.getGroupPoints('RunwayPolygon-1'),
        Runway_Center = {
            line = mist.getGroupPoints('RunwayCenterLine-1'),
            width = 0.762,
        },
    }

    Config.ActiveRunWay = '09'

    Config.Data = {
        ['L-39C'] = {
            NoseWheel = 14, --feet front
            RightWheel = 5, --feet right
            LeftWheel = 5, --feet left
            DrawArguementIDs = {
                LandingGear_N = 0,
                LandingGearDirection_N = 2,
                LandingGear_R = 3,
                LandingGear_L = 5,
        
                Flap_R = 9,
                Flap_L = 10,
        
                TaxiLightID = 209,
                LandingLightID = 208,
        
                TailNumber_Hundreds = 442, --数值 = 值 * 10
                TailNumber_Tens = 31,
                TailNumber_Ones = 32,
            },
            landAlt = 1
        },
    }

    Config.checkLists = {
        ['L-39C'] = {
            BeforeTaxiCheckList = {
                checkListName = '滑行前检查单',
                finish = false,
                [1] = {
                    text = '设置RMI航向: '..Config.RunWay[Config.ActiveRunWay].heading..' - 按需',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        timer.scheduleFunction(function(vars)
                            local context = vars.context
                            context.BeforeTaxiCheckList[vars.itemId].check = true
                        end,{context = player,itemId = itemId},timer.getTime()+10)
                    end,
                },
                [2] = {
                    text = '设置襟翼到起飞档位',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        local L_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_L)
                        local R_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_R)
                        if (L_flapPosition > 0 and L_flapPosition < 1) and (R_flapPosition > 0 and R_flapPosition < 1) then
                            player.BeforeTaxiCheckList[itemId].check = true
                        end
                    end,
                },
                [3] = {
                    text = '滑行灯开启',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        if unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.TaxiLightID) > 0 then
                            player.BeforeTaxiCheckList[itemId].check = true
                        end
                    end,
                },
            },

            BeforeTakeOffCheckList = {
                checkListName = '起飞前检查单',
                finish = false,
                [1] = {
                    text = '设置襟翼到起飞档位',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        local L_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_L)
                        local R_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_R)
                        if (L_flapPosition > 0 and L_flapPosition < 1) and (R_flapPosition > 0 and R_flapPosition < 1) then
                            player.BeforeTakeOffCheckList[itemId].check = true
                        end
                    end,
                },
                [2] = {
                    text = '着陆灯开启',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        if unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.LandingLightID) > 0 then
                            player.BeforeTakeOffCheckList[itemId].check = true
                        end
                    end,
                },
            },

            BeforeLandingCheckList = {
                checkListName = '着陆前检查单',
                finish = false,
                [1] = {
                    text = '设置襟翼到着陆档位',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        local L_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_L)
                        local R_flapPosition = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.Flap_R)
                        if L_flapPosition >= 0.8 and R_flapPosition >= 0.8 then
                            player.BeforeLandingCheckList[itemId].check = true
                        end
                    end,
                },
                [2] = {
                    text = '着陆灯开启',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        if unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.LandingLightID) > 0 then
                            player.BeforeLandingCheckList[itemId].check = true
                        end
                    end,
                },
                [3] = {
                    text = '起落架放出',
                    notice = false,
                    check = false,
                    func = function(player,unit,itemId)
                        local LandingGear_N = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.LandingGear_N)
                        local LandingGear_R = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.LandingGear_R)
                        local LandingGear_L = unit:getDrawArgumentValue(Config.Data['L-39C'].DrawArguementIDs.LandingGear_L)
                        if LandingGear_N > 0.5 and LandingGear_R > 0.5 and LandingGear_L > 0.5 then
                            player.BeforeLandingCheckList[itemId].check = true
                        end
                    end,
                },
            },
        },
    }

end 