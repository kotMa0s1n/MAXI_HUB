--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local StrToNumber = tonumber;
local Byte = string.byte;
local Char = string.char;
local Sub = string.sub;
local Subg = string.gsub;
local Rep = string.rep;
local Concat = table.concat;
local Insert = table.insert;
local LDExp = math.ldexp;
local GetFEnv = getfenv or function()
	return _ENV;
end;
local Setmetatable = setmetatable;
local PCall = pcall;
local Select = select;
local Unpack = unpack or table.unpack;
local ToNumber = tonumber;
local function VMCall(ByteString, vmenv, ...)
	local DIP = 1;
	local repeatNext;
	ByteString = Subg(Sub(ByteString, 5), "..", function(byte)
		if (Byte(byte, 2) == 81) then
			repeatNext = StrToNumber(Sub(byte, 1, 1));
			return "";
		else
			local a = Char(StrToNumber(byte, 16));
			if repeatNext then
				local b = Rep(a, repeatNext);
				repeatNext = nil;
				return b;
			else
				return a;
			end
		end
	end);
	local function gBit(Bit, Start, End)
		if End then
			local Res = (Bit / (2 ^ (Start - 1))) % (2 ^ (((End - 1) - (Start - 1)) + 1));
			return Res - (Res % 1);
		else
			local Plc = 2 ^ (Start - 1);
			return (((Bit % (Plc + Plc)) >= Plc) and 1) or 0;
		end
	end
	local function gBits8()
		local a = Byte(ByteString, DIP, DIP);
		DIP = DIP + 1;
		return a;
	end
	local function gBits16()
		local a, b = Byte(ByteString, DIP, DIP + 2);
		DIP = DIP + 2;
		return (b * 256) + a;
	end
	local function gBits32()
		local a, b, c, d = Byte(ByteString, DIP, DIP + 3);
		DIP = DIP + 4;
		return (d * 16777216) + (c * 65536) + (b * 256) + a;
	end
	local function gFloat()
		local Left = gBits32();
		local Right = gBits32();
		local IsNormal = 1;
		local Mantissa = (gBit(Right, 1, 20) * (2 ^ 32)) + Left;
		local Exponent = gBit(Right, 21, 31);
		local Sign = ((gBit(Right, 32) == 1) and -1) or 1;
		if (Exponent == 0) then
			if (Mantissa == 0) then
				return Sign * 0;
			else
				Exponent = 1;
				IsNormal = 0;
			end
		elseif (Exponent == 2047) then
			return ((Mantissa == 0) and (Sign * (1 / 0))) or (Sign * NaN);
		end
		return LDExp(Sign, Exponent - 1023) * (IsNormal + (Mantissa / (2 ^ 52)));
	end
	local function gString(Len)
		local Str;
		if not Len then
			Len = gBits32();
			if (Len == 0) then
				return "";
			end
		end
		Str = Sub(ByteString, DIP, (DIP + Len) - 1);
		DIP = DIP + Len;
		local FStr = {};
		for Idx = 1, #Str do
			FStr[Idx] = Char(Byte(Sub(Str, Idx, Idx)));
		end
		return Concat(FStr);
	end
	local gInt = gBits32;
	local function _R(...)
		return {...}, Select("#", ...);
	end
	local function Deserialize()
		local Instrs = {};
		local Functions = {};
		local Lines = {};
		local Chunk = {Instrs,Functions,nil,Lines};
		local ConstCount = gBits32();
		local Consts = {};
		for Idx = 1, ConstCount do
			local Type = gBits8();
			local Cons;
			if (Type == 1) then
				Cons = gBits8() ~= 0;
			elseif (Type == 2) then
				Cons = gFloat();
			elseif (Type == 3) then
				Cons = gString();
			end
			Consts[Idx] = Cons;
		end
		Chunk[3] = gBits8();
		for Idx = 1, gBits32() do
			local Descriptor = gBits8();
			if (gBit(Descriptor, 1, 1) == 0) then
				local Type = gBit(Descriptor, 2, 3);
				local Mask = gBit(Descriptor, 4, 6);
				local Inst = {gBits16(),gBits16(),nil,nil};
				if (Type == 0) then
					Inst[3] = gBits16();
					Inst[4] = gBits16();
				elseif (Type == 1) then
					Inst[3] = gBits32();
				elseif (Type == 2) then
					Inst[3] = gBits32() - (2 ^ 16);
				elseif (Type == 3) then
					Inst[3] = gBits32() - (2 ^ 16);
					Inst[4] = gBits16();
				end
				if (gBit(Mask, 1, 1) == 1) then
					Inst[2] = Consts[Inst[2]];
				end
				if (gBit(Mask, 2, 2) == 1) then
					Inst[3] = Consts[Inst[3]];
				end
				if (gBit(Mask, 3, 3) == 1) then
					Inst[4] = Consts[Inst[4]];
				end
				Instrs[Idx] = Inst;
			end
		end
		for Idx = 1, gBits32() do
			Functions[Idx - 1] = Deserialize();
		end
		return Chunk;
	end
	local function Wrap(Chunk, Upvalues, Env)
		local Instr = Chunk[1];
		local Proto = Chunk[2];
		local Params = Chunk[3];
		return function(...)
			local Instr = Instr;
			local Proto = Proto;
			local Params = Params;
			local _R = _R;
			local VIP = 1;
			local Top = -1;
			local Vararg = {};
			local Args = {...};
			local PCount = Select("#", ...) - 1;
			local Lupvals = {};
			local Stk = {};
			for Idx = 0, PCount do
				if (Idx >= Params) then
					Vararg[Idx - Params] = Args[Idx + 1];
				else
					Stk[Idx] = Args[Idx + 1];
				end
			end
			local Varargsz = (PCount - Params) + 1;
			local Inst;
			local Enum;
			while true do
				Inst = Instr[VIP];
				Enum = Inst[1];
				if (Enum <= 40) then
					if (Enum <= 19) then
						if (Enum <= 9) then
							if (Enum <= 4) then
								if (Enum <= 1) then
									if (Enum > 0) then
										local A = Inst[2];
										do
											return Stk[A](Unpack(Stk, A + 1, Inst[3]));
										end
									else
										local A = Inst[2];
										local T = Stk[A];
										local B = Inst[3];
										for Idx = 1, B do
											T[Idx] = Stk[A + Idx];
										end
									end
								elseif (Enum <= 2) then
									do
										return Stk[Inst[2]]();
									end
								elseif (Enum > 3) then
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								elseif (Stk[Inst[2]] < Stk[Inst[4]]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 6) then
								if (Enum > 5) then
									if (Stk[Inst[2]] == Inst[4]) then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								elseif (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 7) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif (Enum > 8) then
								Stk[Inst[2]] = Inst[3];
							else
								Stk[Inst[2]]();
							end
						elseif (Enum <= 14) then
							if (Enum <= 11) then
								if (Enum == 10) then
									local A = Inst[2];
									local T = Stk[A];
									local B = Inst[3];
									for Idx = 1, B do
										T[Idx] = Stk[A + Idx];
									end
								else
									local A = Inst[2];
									Stk[A] = Stk[A]();
								end
							elseif (Enum <= 12) then
								for Idx = Inst[2], Inst[3] do
									Stk[Idx] = nil;
								end
							elseif (Enum > 13) then
								local A = Inst[2];
								local Results = {Stk[A]()};
								local Limit = Inst[4];
								local Edx = 0;
								for Idx = A, Limit do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 16) then
							if (Enum > 15) then
								Stk[Inst[2]] = Inst[3] ~= 0;
							else
								local A = Inst[2];
								Stk[A] = Stk[A]();
							end
						elseif (Enum <= 17) then
							if (Stk[Inst[2]] < Stk[Inst[4]]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 18) then
							local B = Inst[3];
							local K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
						else
							do
								return Stk[Inst[2]];
							end
						end
					elseif (Enum <= 29) then
						if (Enum <= 24) then
							if (Enum <= 21) then
								if (Enum > 20) then
									Stk[Inst[2]] = Inst[3] ~= 0;
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 22) then
								Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
							elseif (Enum == 23) then
								Stk[Inst[2]] = Inst[3];
							else
								Stk[Inst[2]] = Upvalues[Inst[3]];
							end
						elseif (Enum <= 26) then
							if (Enum > 25) then
								if Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 27) then
							do
								return;
							end
						elseif (Enum > 28) then
							local A = Inst[2];
							do
								return Unpack(Stk, A, A + Inst[3]);
							end
						else
							local NewProto = Proto[Inst[3]];
							local NewUvals;
							local Indexes = {};
							NewUvals = Setmetatable({}, {__index=function(_, Key)
								local Val = Indexes[Key];
								return Val[1][Val[2]];
							end,__newindex=function(_, Key, Value)
								local Val = Indexes[Key];
								Val[1][Val[2]] = Value;
							end});
							for Idx = 1, Inst[4] do
								VIP = VIP + 1;
								local Mvm = Instr[VIP];
								if (Mvm[1] == 60) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum <= 34) then
						if (Enum <= 31) then
							if (Enum > 30) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							else
								local A = Inst[2];
								Stk[A](Stk[A + 1]);
							end
						elseif (Enum <= 32) then
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						elseif (Enum == 33) then
							local A = Inst[2];
							local Results = {Stk[A]()};
							local Limit = Inst[4];
							local Edx = 0;
							for Idx = A, Limit do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						end
					elseif (Enum <= 37) then
						if (Enum <= 35) then
							Stk[Inst[2]] = Inst[3] ~= 0;
						elseif (Enum == 36) then
							Stk[Inst[2]] = Stk[Inst[3]][Stk[Inst[4]]];
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
						end
					elseif (Enum <= 38) then
						Stk[Inst[2]][Stk[Inst[3]]] = Stk[Inst[4]];
					elseif (Enum > 39) then
						local A = Inst[2];
						local B = Stk[Inst[3]];
						Stk[A + 1] = B;
						Stk[A] = B[Inst[4]];
					else
						local A = Inst[2];
						local T = Stk[A];
						for Idx = A + 1, Inst[3] do
							Insert(T, Stk[Idx]);
						end
					end
				elseif (Enum <= 60) then
					if (Enum <= 50) then
						if (Enum <= 45) then
							if (Enum <= 42) then
								if (Enum == 41) then
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								else
									Stk[Inst[2]] = Env[Inst[3]];
								end
							elseif (Enum <= 43) then
								Stk[Inst[2]] = Upvalues[Inst[3]];
							elseif (Enum == 44) then
								Stk[Inst[2]][Inst[3]] = Inst[4];
							else
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							end
						elseif (Enum <= 47) then
							if (Enum > 46) then
								VIP = Inst[3];
							else
								Stk[Inst[2]][Stk[Inst[3]]] = Stk[Inst[4]];
							end
						elseif (Enum <= 48) then
							local A = Inst[2];
							Stk[A](Stk[A + 1]);
						elseif (Enum == 49) then
							local A = Inst[2];
							local C = Inst[4];
							local CB = A + 2;
							local Result = {Stk[A](Stk[A + 1], Stk[CB])};
							for Idx = 1, C do
								Stk[CB + Idx] = Result[Idx];
							end
							local R = Result[1];
							if R then
								Stk[CB] = R;
								VIP = Inst[3];
							else
								VIP = VIP + 1;
							end
						else
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						end
					elseif (Enum <= 55) then
						if (Enum <= 52) then
							if (Enum == 51) then
								if (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local B = Inst[3];
								local K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
							end
						elseif (Enum <= 53) then
							Stk[Inst[2]] = Env[Inst[3]];
						elseif (Enum == 54) then
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
						else
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						end
					elseif (Enum <= 57) then
						if (Enum > 56) then
							local A = Inst[2];
							local B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 58) then
						local A = Inst[2];
						local C = Inst[4];
						local CB = A + 2;
						local Result = {Stk[A](Stk[A + 1], Stk[CB])};
						for Idx = 1, C do
							Stk[CB + Idx] = Result[Idx];
						end
						local R = Result[1];
						if R then
							Stk[CB] = R;
							VIP = Inst[3];
						else
							VIP = VIP + 1;
						end
					elseif (Enum > 59) then
						Stk[Inst[2]] = Stk[Inst[3]];
					else
						Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
					end
				elseif (Enum <= 70) then
					if (Enum <= 65) then
						if (Enum <= 62) then
							if (Enum == 61) then
								Stk[Inst[2]] = Stk[Inst[3]];
							else
								Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
							end
						elseif (Enum <= 63) then
							if (Stk[Inst[2]] == Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 64) then
							Stk[Inst[2]] = {};
						else
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						end
					elseif (Enum <= 67) then
						if (Enum == 66) then
							do
								return;
							end
						else
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						end
					elseif (Enum <= 68) then
						local NewProto = Proto[Inst[3]];
						local NewUvals;
						local Indexes = {};
						NewUvals = Setmetatable({}, {__index=function(_, Key)
							local Val = Indexes[Key];
							return Val[1][Val[2]];
						end,__newindex=function(_, Key, Value)
							local Val = Indexes[Key];
							Val[1][Val[2]] = Value;
						end});
						for Idx = 1, Inst[4] do
							VIP = VIP + 1;
							local Mvm = Instr[VIP];
							if (Mvm[1] == 60) then
								Indexes[Idx - 1] = {Stk,Mvm[3]};
							else
								Indexes[Idx - 1] = {Upvalues,Mvm[3]};
							end
							Lupvals[#Lupvals + 1] = Indexes;
						end
						Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
					elseif (Enum == 69) then
						Stk[Inst[2]] = {};
					else
						do
							return Stk[Inst[2]];
						end
					end
				elseif (Enum <= 75) then
					if (Enum <= 72) then
						if (Enum > 71) then
							Upvalues[Inst[3]] = Stk[Inst[2]];
						elseif not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 73) then
						local A = Inst[2];
						Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
					elseif (Enum == 74) then
						local A = Inst[2];
						do
							return Unpack(Stk, A, Top);
						end
					else
						Stk[Inst[2]]();
					end
				elseif (Enum <= 78) then
					if (Enum <= 76) then
						local A = Inst[2];
						local Results = {Stk[A](Stk[A + 1])};
						local Edx = 0;
						for Idx = A, Inst[4] do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
					elseif (Enum == 77) then
						do
							return Stk[Inst[2]]();
						end
					else
						Upvalues[Inst[3]] = Stk[Inst[2]];
					end
				elseif (Enum <= 79) then
					local A = Inst[2];
					do
						return Unpack(Stk, A, Top);
					end
				elseif (Enum > 80) then
					if not Stk[Inst[2]] then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				else
					local A = Inst[2];
					do
						return Stk[A](Unpack(Stk, A + 1, Inst[3]));
					end
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!3C3Q0003043Q0067616D65030A3Q0047657453657276696365030B3Q00482Q74705365727669636503043Q0046494C4503183Q006D6178692D6875622D7363722D636F6E6669672E6A736F6E03083Q0044454641554C545303143Q0073746174696F6E506C6174666F726D53702Q6564026Q003E40030B3Q00617453746174696F6E4D69028Q0003123Q00706C6174666F726D412Q70726F6163684D69026Q33D33F030E3Q0064616E6765725369676E616C4D69029A5Q99B93F03103Q006272616B6553702Q65644D617267696E030F3Q0073746F2Q70656453702Q65644D6178026Q00F03F03103Q006E6F4C696D6974734D617853702Q6564026Q00594003113Q00642Q6F725072652Q73432Q6F6C646F776E026Q00104003123Q00642Q6F72416374696F6E44656C6179536563027Q004003163Q00726567756C617253746174696F6E4477652Q6C536563026Q00144003103Q007465726D696E75734477652Q6C536563030D3Q00706C6174666F726D4477652Q6C03013Q0031026Q00184003013Q003203013Q0033026Q002A4003013Q003403013Q0035026Q00224003013Q003603173Q006E6578744C65674166746572442Q6F724F70656E536563026Q00394003163Q006E6578744C6567416674657253752Q6D617279536563030D3Q0061777354696D656F757453656303063Q004C494D495453026Q004E40026Q00D03F027B14AE47E17A843F026Q00E03F026Q002E40026Q002440026Q004440026Q005E40026Q003440025Q0080564003103Q0063616E557365436F6E66696746696C65030D3Q00636C6F6E6544656661756C7473030D3Q00612Q706C7944656661756C747303053Q006D65726765030C3Q00726561645261775461626C65030A3Q0077726974655461626C65030A3Q0072657061697246696C6503043Q006C6F616403043Q0073617665008D3Q0012353Q00013Q0020285Q0002001209000200034Q00493Q000200022Q004100015Q00302C0001000400052Q004100023Q000F00302C00020007000800302C00020009000A00302C0002000B000C00302C0002000D000E00302C0002000F000A00302C00020010001100302C00020012001300302C00020014001500302C00020016001700302C00020018001900302C0002001A00192Q004100033Q000600302C0003001C001D00302C0003001E001D00302C0003001F002000302C00030021002000302C00030022002300302C00030024002300103B0002001B000300302C00020025002600302C00020027001900302C00020028001D00103B0001000600022Q004100023Q000F2Q0041000300023Q001209000400193Q0012090005002A4Q000A00030002000100103B0002000700032Q0041000300023Q0012090004000A3Q0012090005002B4Q000A00030002000100103B0002000900032Q0041000300023Q0012090004000E3Q001209000500114Q000A00030002000100103B0002000B00032Q0041000300023Q0012090004002C3Q0012090005002D4Q000A00030002000100103B0002000D00032Q0041000300023Q0012090004000A3Q0012090005002E4Q000A00030002000100103B0002000F00032Q0041000300023Q0012090004000A3Q0012090005002F4Q000A00030002000100103B0002001000032Q0041000300023Q001209000400303Q001209000500314Q000A00030002000100103B0002001200032Q0041000300023Q001209000400113Q001209000500324Q000A00030002000100103B0002001400032Q0041000300023Q0012090004000A3Q0012090005002F4Q000A00030002000100103B0002001600032Q0041000300023Q001209000400113Q001209000500084Q000A00030002000100103B0002001800032Q0041000300023Q001209000400113Q001209000500084Q000A00030002000100103B0002001A00032Q0041000300023Q001209000400113Q001209000500084Q000A00030002000100103B0002001B00032Q0041000300023Q001209000400193Q001209000500334Q000A00030002000100103B0002002500032Q0041000300023Q001209000400113Q001209000500084Q000A00030002000100103B0002002700032Q0041000300023Q001209000400173Q001209000500324Q000A00030002000100103B00020028000300103B00010029000200023700025Q000237000300013Q00103B000100340003000237000300023Q00064400040003000100012Q003C3Q00013Q00103B00010035000400064400040004000100012Q003C3Q00013Q00103B00010036000400064400040005000100022Q003C3Q00014Q003C3Q00023Q00103B00010037000400064400040006000100032Q003C3Q00014Q003C3Q00034Q003C7Q00103B00010038000400064400040007000100022Q003C3Q00014Q003C7Q00103B00010039000400064400040008000100012Q003C3Q00013Q00103B0001003A000400064400040009000100012Q003C3Q00013Q00103B0001003B00040006440004000A000100012Q003C3Q00013Q00103B0001003C00042Q0012000100024Q001B3Q00013Q000B3Q00013Q0003083Q00746F6E756D626572030E3Q001235000300014Q003D00046Q0025000300020002000651000300060001000100042F3Q000600012Q0012000100023Q000611000300090001000100042F3Q000900012Q0012000100023Q0006110002000C0001000300042F3Q000C00012Q0012000200024Q0012000300024Q001B3Q00017Q00053Q0003063Q00747970656F6603083Q007265616466696C6503083Q0066756E6374696F6E03093Q00777269746566696C6503063Q00697366696C6500133Q0012353Q00013Q001235000100024Q00253Q000200020026063Q000F0001000300042F3Q000F00010012353Q00013Q001235000100044Q00253Q000200020026063Q000F0001000300042F3Q000F00010012353Q00013Q001235000100054Q00253Q000200020026053Q00100001000300042F3Q001000012Q00158Q00103Q00014Q00123Q00024Q001B3Q00017Q00083Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q0008402Q033Q00EFBBBF026Q00104001143Q001235000100014Q003D00026Q0025000100020002002606000100070001000200042F3Q000700010026063Q00080001000300042F3Q000800012Q00123Q00023Q00202800013Q0004001209000300053Q001209000400064Q0049000100040002002606000100120001000700042F3Q0012000100202800013Q0004001209000300084Q0050000100034Q004F00016Q00123Q00024Q001B3Q00017Q00033Q0003053Q00706169727303083Q0044454641554C5453030D3Q00706C6174666F726D4477652Q6C00184Q00417Q001235000100014Q002B00025Q0020400002000200022Q004C00010002000300042F3Q00140001002606000400130001000300042F3Q001300012Q004100065Q00103B3Q00030006001235000600014Q003D000700054Q004C00060002000800042F3Q00100001002040000B3Q00032Q0026000B0009000A0006310006000E0001000200042F3Q000E000100042F3Q001400012Q00263Q00040005000631000100060001000200042F3Q000600012Q00123Q00024Q001B3Q00017Q00033Q00030D3Q00636C6F6E6544656661756C747303053Q007061697273030D3Q00706C6174666F726D4477652Q6C01194Q002B00015Q0020400001000100012Q000F000100010002001235000200024Q003D000300014Q004C00020002000400042F3Q00150001002606000500140001000300042F3Q001400012Q004100075Q00103B3Q00030007001235000700024Q003D000800064Q004C00070002000900042F3Q00110001002040000C3Q00032Q0026000C000A000B0006310007000F0001000200042F3Q000F000100042F3Q001500012Q00263Q00050006000631000200070001000200042F3Q000700012Q00123Q00024Q001B3Q00017Q00093Q00030D3Q00636C6F6E6544656661756C747303043Q007479706503053Q007461626C6503053Q00706169727303063Q004C494D495453030D3Q00706C6174666F726D4477652Q6C00026Q00F03F027Q004001344Q002B00015Q0020400001000100012Q000F000100010002001235000200024Q003D00036Q0025000200020002002605000200090001000300042F3Q000900012Q0012000100023Q001235000200044Q002B00035Q0020400003000300052Q004C00020002000400042F3Q00300001002606000500270001000600042F3Q0027000100204000073Q0006001235000800024Q003D000900074Q0025000800020002002606000800300001000300042F3Q00300001001235000800043Q0020400009000100062Q004C00080002000A00042F3Q002400012Q0016000D0007000B002605000D00240001000700042F3Q00240001002040000D000100062Q002B000E00014Q0016000F0007000B0020400010000600080020400011000600092Q0049000E001100022Q0026000D000B000E0006310008001A0001000200042F3Q001A000100042F3Q003000012Q001600073Q0005002605000700300001000700042F3Q003000012Q002B000700014Q001600083Q0005002040000900060008002040000A000600092Q00490007000A00022Q00260001000500070006310002000E0001000200042F3Q000E00012Q0012000100024Q001B3Q00017Q000C3Q0003103Q0063616E557365436F6E66696746696C6503063Q00697366696C6503043Q0046494C4503073Q006D692Q73696E6703053Q007063612Q6C03043Q007479706503063Q00737472696E6703093Q00726561645F6661696C034Q0003053Q00656D70747903053Q007461626C65030C3Q006A736F6E5F696E76616C696400384Q002B7Q0020405Q00012Q000F3Q000100020006193Q000B00013Q00042F3Q000B00010012353Q00024Q002B00015Q0020400001000100032Q00253Q000200020006513Q000E0001000100042F3Q000E00012Q00327Q001209000100044Q00433Q00033Q0012353Q00053Q00064400013Q000100012Q00188Q004C3Q000200010006193Q001900013Q00042F3Q00190001001235000200064Q003D000300014Q00250002000200020026050002001C0001000700042F3Q001C00012Q0032000200023Q001209000300084Q0043000200034Q002B000200014Q003D000300014Q00250002000200022Q003D000100023Q002606000100250001000900042F3Q002500012Q0032000200023Q0012090003000A4Q0043000200033Q001235000200053Q00064400030001000100022Q00183Q00024Q003C3Q00014Q004C0002000200030006190002003100013Q00042F3Q00310001001235000400064Q003D000500034Q0025000400020002002605000400340001000B00042F3Q003400012Q0032000400043Q0012090005000C4Q0043000400034Q003D000400034Q0032000500054Q0043000400034Q001B3Q00013Q00023Q00023Q0003083Q007265616466696C6503043Q0046494C4500063Q0012353Q00014Q002B00015Q0020400001000100022Q00503Q00014Q004F8Q001B3Q00017Q00013Q00030A3Q004A534F4E4465636F646500064Q002B7Q0020285Q00012Q002B000200014Q00503Q00024Q004F8Q001B3Q00017Q00083Q0003103Q0063616E557365436F6E66696746696C6503043Q007479706503053Q007461626C6503053Q007063612Q6C03063Q00737472696E67034Q0003043Q007761726E03203Q005B5343525D20436F6E666967204A534F4E20656E636F6465206661696C65643A01294Q002B00015Q0020400001000100012Q000F0001000100020006190001000A00013Q00042F3Q000A0001001235000100024Q003D00026Q00250001000200020026050001000C0001000300042F3Q000C00012Q001000016Q0012000100023Q001235000100043Q00064400023Q000100022Q00183Q00014Q003C8Q004C0001000200020006190001001A00013Q00042F3Q001A0001001235000300024Q003D000400024Q00250003000200020026060003001A0001000500042F3Q001A0001002606000200200001000600042F3Q00200001001235000300073Q001209000400084Q003D000500024Q00070003000500012Q001000036Q0012000300024Q001000035Q001235000400043Q00064400050001000100032Q00188Q003C3Q00024Q003C3Q00034Q001E0004000200012Q0012000300024Q001B3Q00013Q00023Q00013Q00030A3Q004A534F4E456E636F646500064Q002B7Q0020285Q00012Q002B000200014Q00503Q00024Q004F8Q001B3Q00017Q00023Q0003093Q00777269746566696C6503043Q0046494C4500083Q0012353Q00014Q002B00015Q0020400001000100022Q002B000200014Q00073Q000200012Q00103Q00014Q00483Q00024Q001B3Q00017Q00053Q00030D3Q00636C6F6E6544656661756C7473030A3Q0077726974655461626C6503043Q007761726E032D3Q005B5343525D20436F6E666967207265706169726564202D3E2064656661756C7473207772692Q74656E20746F2003043Q0046494C4500114Q002B7Q0020405Q00012Q000F3Q000100022Q002B00015Q0020400001000100022Q003D00026Q00250001000200020006190001000F00013Q00042F3Q000F0001001235000200033Q001209000300044Q002B00045Q0020400004000400052Q00340003000300042Q001E0002000200012Q0012000100024Q001B3Q00017Q000A3Q0003103Q0063616E557365436F6E66696746696C65030D3Q00636C6F6E6544656661756C7473030C3Q00726561645261775461626C65030C3Q006A736F6E5F696E76616C696403043Q007761726E03063Q005B5343525D2003043Q0046494C4503233Q0020697320696E76616C6964204A534F4E20E28094207573696E672064656661756C7473030A3Q0072657061697246696C6503053Q006D6572676500244Q002B7Q0020405Q00012Q000F3Q000100020006513Q00090001000100042F3Q000900012Q002B7Q0020405Q00022Q004D3Q00014Q004F8Q002B7Q0020405Q00032Q00213Q000100010006513Q001E0001000100042F3Q001E00010026060001001A0001000400042F3Q001A0001001235000200053Q001209000300064Q002B00045Q002040000400040007001209000500084Q00340003000300052Q001E0002000200012Q002B00025Q0020400002000200092Q004B0002000100012Q002B00025Q0020400002000200022Q004D000200014Q004F00026Q002B00025Q00204000020002000A2Q003D00036Q0050000200034Q004F00026Q001B3Q00017Q00043Q0003043Q007479706503053Q007461626C6503053Q006D65726765030A3Q0077726974655461626C6501113Q001235000100014Q003D00026Q0025000100020002002605000100070001000200042F3Q000700012Q001000016Q0012000100024Q002B00015Q0020400001000100032Q003D00026Q00250001000200022Q002B00025Q0020400002000200042Q003D000300014Q0050000200034Q004F00026Q001B3Q00017Q00", GetFEnv(), ...);