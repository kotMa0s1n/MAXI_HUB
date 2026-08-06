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
				if (Enum <= 39) then
					if (Enum <= 19) then
						if (Enum <= 9) then
							if (Enum <= 4) then
								if (Enum <= 1) then
									if (Enum == 0) then
										Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
									else
										do
											return;
										end
									end
								elseif (Enum <= 2) then
									do
										return Stk[Inst[2]];
									end
								elseif (Enum > 3) then
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								else
									Stk[Inst[2]]();
								end
							elseif (Enum <= 6) then
								if (Enum > 5) then
									local A = Inst[2];
									local T = Stk[A];
									local B = Inst[3];
									for Idx = 1, B do
										T[Idx] = Stk[A + Idx];
									end
								else
									Stk[Inst[2]] = Inst[3];
								end
							elseif (Enum <= 7) then
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							elseif (Enum > 8) then
								if (Stk[Inst[2]] == Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Upvalues[Inst[3]];
							end
						elseif (Enum <= 14) then
							if (Enum <= 11) then
								if (Enum > 10) then
									local A = Inst[2];
									local B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
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
										if (Mvm[1] == 33) then
											Indexes[Idx - 1] = {Stk,Mvm[3]};
										else
											Indexes[Idx - 1] = {Upvalues,Mvm[3]};
										end
										Lupvals[#Lupvals + 1] = Indexes;
									end
									Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
								end
							elseif (Enum <= 12) then
								local A = Inst[2];
								local Results, Limit = _R(Stk[A](Stk[A + 1]));
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							elseif (Enum > 13) then
								if (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								local A = Inst[2];
								do
									return Unpack(Stk, A, Top);
								end
							end
						elseif (Enum <= 16) then
							if (Enum > 15) then
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							else
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						elseif (Enum <= 17) then
							local A = Inst[2];
							Stk[A] = Stk[A]();
						elseif (Enum > 18) then
							Stk[Inst[2]] = #Stk[Inst[3]];
						else
							local A = Inst[2];
							local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						end
					elseif (Enum <= 29) then
						if (Enum <= 24) then
							if (Enum <= 21) then
								if (Enum > 20) then
									local B = Stk[Inst[4]];
									if not B then
										VIP = VIP + 1;
									else
										Stk[Inst[2]] = B;
										VIP = Inst[3];
									end
								else
									Stk[Inst[2]] = Env[Inst[3]];
								end
							elseif (Enum <= 22) then
								local A = Inst[2];
								do
									return Unpack(Stk, A, Top);
								end
							elseif (Enum > 23) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								Stk[Inst[2]] = {};
							end
						elseif (Enum <= 26) then
							if (Enum == 25) then
								local A = Inst[2];
								Stk[A](Stk[A + 1]);
							else
								local A = Inst[2];
								do
									return Unpack(Stk, A, A + Inst[3]);
								end
							end
						elseif (Enum <= 27) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						elseif (Enum == 28) then
							Stk[Inst[2]] = Env[Inst[3]];
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 34) then
						if (Enum <= 31) then
							if (Enum > 30) then
								if not Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Upvalues[Inst[3]];
							end
						elseif (Enum <= 32) then
							do
								return Stk[Inst[2]];
							end
						elseif (Enum == 33) then
							Stk[Inst[2]] = Stk[Inst[3]];
						else
							local B = Inst[3];
							local K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
						end
					elseif (Enum <= 36) then
						if (Enum == 35) then
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							Stk[Inst[2]] = Stk[Inst[3]];
						end
					elseif (Enum <= 37) then
						for Idx = Inst[2], Inst[3] do
							Stk[Idx] = nil;
						end
					elseif (Enum == 38) then
						local A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
					else
						local A = Inst[2];
						Stk[A] = Stk[A]();
					end
				elseif (Enum <= 59) then
					if (Enum <= 49) then
						if (Enum <= 44) then
							if (Enum <= 41) then
								if (Enum > 40) then
									do
										return;
									end
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 42) then
								local A = Inst[2];
								local Results, Limit = _R(Stk[A](Stk[A + 1]));
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							elseif (Enum > 43) then
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							else
								local A = Inst[2];
								do
									return Unpack(Stk, A, A + Inst[3]);
								end
							end
						elseif (Enum <= 46) then
							if (Enum == 45) then
								local A = Inst[2];
								Stk[A](Stk[A + 1]);
							else
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 47) then
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						elseif (Enum > 48) then
							local A = Inst[2];
							local T = Stk[A];
							for Idx = A + 1, Inst[3] do
								Insert(T, Stk[Idx]);
							end
						elseif (Stk[Inst[2]] < Stk[Inst[4]]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 54) then
						if (Enum <= 51) then
							if (Enum == 50) then
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
							elseif Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 52) then
							Stk[Inst[2]] = {};
						elseif (Enum == 53) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Top));
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
								if (Mvm[1] == 33) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum <= 56) then
						if (Enum > 55) then
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
					elseif (Enum <= 57) then
						Stk[Inst[2]] = Inst[3] ~= 0;
						VIP = VIP + 1;
					elseif (Enum > 58) then
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
					elseif (Stk[Inst[2]] < Stk[Inst[4]]) then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 69) then
					if (Enum <= 64) then
						if (Enum <= 61) then
							if (Enum > 60) then
								Stk[Inst[2]] = Inst[3];
							elseif Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 62) then
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						elseif (Enum > 63) then
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						else
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						end
					elseif (Enum <= 66) then
						if (Enum == 65) then
							Stk[Inst[2]] = Inst[3] ~= 0;
						else
							local A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						end
					elseif (Enum <= 67) then
						local A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum > 68) then
						local B = Stk[Inst[4]];
						if not B then
							VIP = VIP + 1;
						else
							Stk[Inst[2]] = B;
							VIP = Inst[3];
						end
					else
						Stk[Inst[2]]();
					end
				elseif (Enum <= 74) then
					if (Enum <= 71) then
						if (Enum == 70) then
							Stk[Inst[2]] = Inst[3] ~= 0;
						else
							Stk[Inst[2]][Inst[3]] = Inst[4];
						end
					elseif (Enum <= 72) then
						if (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum == 73) then
						if not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					else
						local A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
					end
				elseif (Enum <= 77) then
					if (Enum <= 75) then
						Stk[Inst[2]] = Inst[3] ~= 0;
						VIP = VIP + 1;
					elseif (Enum == 76) then
						Stk[Inst[2]] = #Stk[Inst[3]];
					else
						local A = Inst[2];
						local T = Stk[A];
						local B = Inst[3];
						for Idx = 1, B do
							T[Idx] = Stk[A + Idx];
						end
					end
				elseif (Enum <= 78) then
					local A = Inst[2];
					local B = Stk[Inst[3]];
					Stk[A + 1] = B;
					Stk[A] = B[Inst[4]];
				elseif (Enum == 79) then
					local A = Inst[2];
					Stk[A](Unpack(Stk, A + 1, Top));
				else
					VIP = Inst[3];
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!2A3Q002Q033Q00312E33033E3Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F5343522F033E3Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F7363722F03383Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F5343522F03383Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F7363722F030C3Q006C61756E636865722E6C756103113Q007363722D622Q6F7473747261702E6C7561030D3Q007363722D6C6F6769632E6C7561030E3Q007363722D6C6F63616C652E6C7561030E3Q007363722D636F6E6669672E6C7561030F3Q006D6178692D6875622D75692E6C756103173Q0073746570666F72642D636F756E74792D7261696C776179026Q00504003063Q00747970656F6603093Q00777269746566696C6503083Q0066756E6374696F6E03083Q007265616466696C6503063Q00697366696C6503053Q00652Q726F7203363Q005B5343525D20D09DD183D0B6D0B5D0BD206578656375746F7220D18120777269746566696C652F7265616466696C652F697366696C65030F3Q005343525F4F2Q66696369616C526177026Q00F03F030D3Q005343525F4C6F6164657255726C030A3Q006C6F616465722E6C756103113Q005343525F4C6F6164657256657273696F6E030C3Q005343525F5265706F4F6E6C792Q01030E3Q004D617869487562536B69704B657903113Q004D61786948756247616D6553637269707403053Q007072696E74030E3Q005B5343525D206C6F616465722076030C3Q00207374617274696E673Q2E030A3Q006D616B65666F6C64657203053Q007063612Q6C03063Q0069706169727303013Q002F030D3Q002F6C61756E636865722E6C7561030A3Q006C6F6164737472696E67030D3Q00406C61756E636865722E6C756103183Q005B5343525D206C61756E6368657220636F6D70696C653A2003083Q00746F737472696E6703193Q005B5343525D2072752Q6E696E67206C61756E636865723Q2E00743Q0012053Q00014Q0017000100043Q001205000200023Q001205000300033Q001205000400043Q001205000500054Q004D0001000400012Q0017000200063Q001205000300063Q001205000400073Q001205000500083Q001205000600093Q0012050007000A3Q0012050008000B4Q004D0002000600010012050003000C3Q0012050004000D3Q00024000055Q000240000600013Q000240000700023Q000240000800033Q000240000900043Q00060A000A0005000100032Q00213Q00084Q00213Q00094Q00213Q00043Q00060A000B0006000100052Q00213Q00064Q00213Q00014Q00213Q00074Q00213Q000A4Q00217Q001214000C000E3Q001214000D000F4Q004A000C00020002002648000C002F000100100004283Q002F0001001214000C000E3Q001214000D00114Q004A000C00020002002648000C002F000100100004283Q002F0001001214000C000E3Q001214000D00124Q004A000C00020002002638000C0032000100100004283Q00320001001214000C00133Q001205000D00144Q0019000C000200012Q0024000C00054Q0027000C0001000200202F000D00010016001004000C0015000D00202F000D00010016001205000E00184Q0037000D000D000E001004000C0017000D001004000C00193Q00301D000C001A001B00301D000C001C001B00301D000C001D001B001214000D001E3Q001205000E001F4Q0024000F5Q001205001000204Q0037000E000E00102Q0019000D00020001001214000D000E3Q001214000E00214Q004A000D00020002002648000D004D000100100004283Q004D0001001214000D00223Q001214000E00214Q0024000F00034Q0026000D000F0001001214000D00234Q0024000E00024Q0007000D0002000F0004283Q005A00010012140012000F4Q0024001300033Q001205001400244Q0024001500114Q00370013001300152Q00240014000B4Q0024001500114Q002A001400154Q004F00123Q000100063B000D0051000100020004283Q00510001001214000D00114Q0024000E00033Q001205000F00254Q0037000E000E000F2Q004A000D00020002001214000E00264Q0024000F000D3Q001205001000274Q0018000E0010000F00061F000E006E000100010004283Q006E0001001214001000133Q001205001100283Q001214001200294Q00240013000F4Q004A0012000200022Q00370011001100122Q00190010000200010012140010001E3Q0012050011002A4Q00190010000200012Q00240010000E4Q00030010000100012Q00013Q00013Q00073Q00043Q0003063Q00747970656F6603073Q0067657467656E7603083Q0066756E6374696F6E03023Q005F47000C3Q0012143Q00013Q001214000100024Q004A3Q000200020026483Q0009000100030004283Q000900010012143Q00024Q00273Q0001000200061F3Q000A000100010004283Q000A00010012143Q00044Q00203Q00024Q00013Q00017Q000A3Q0003063Q00747970656F6603023Q006F7303053Q007461626C6503043Q0074696D65028Q0003043Q006D61746803063Q0072616E646F6D025Q00408F40024Q008087C34003083Q00746F737472696E6700293Q0012143Q00013Q001214000100024Q004A3Q000200020026483Q000E000100030004283Q000E00010012143Q00023Q00202F5Q00040006333Q000E00013Q0004283Q000E00010012143Q00023Q00202F5Q00042Q00273Q0001000200061F3Q000F000100010004283Q000F00010012053Q00053Q001214000100013Q001214000200064Q004A0001000200020026480001001F000100030004283Q001F0001001214000100063Q00202F0001000100070006330001001F00013Q0004283Q001F0001001214000100063Q00202F000100010007001205000200083Q001205000300094Q002300010003000200061F00010020000100010004283Q00200001001205000100053Q0012140002000A4Q002400036Q004A0002000200020012140003000A4Q0024000400014Q004A0003000200022Q00370002000200032Q0020000200024Q00013Q00017Q00113Q0003063Q00747970656F6603043Q0067616D6503073Q00482Q747047657403083Q0066756E6374696F6E03053Q007063612Q6C030A3Q0047657453657276696365030B3Q00482Q74705365727669636503083Q004765744173796E632Q033Q0073796E03053Q007461626C6503073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455403043Q007479706503043Q00426F6479030C3Q00682Q74705F72657175657374019F3Q00024000015Q001214000200013Q001214000300023Q00202F0003000300032Q004A00020002000200264800020024000100040004283Q00240001001214000200053Q001214000300023Q00202F0003000300032Q002400046Q0046000500014Q00180002000500030006330002001500013Q0004283Q001500012Q0024000400014Q0024000500034Q004A0004000200020006330004001500013Q0004283Q001500012Q0020000300023Q001214000400053Q001214000500023Q00202F0005000500032Q002400066Q00180004000600052Q0024000300054Q0024000200043Q0006330002002400013Q0004283Q002400012Q0024000400014Q0024000500034Q004A0004000200020006330004002400013Q0004283Q002400012Q0020000300023Q001214000200023Q00204E000200020006001205000400074Q00230002000400020006330002004C00013Q0004283Q004C0001001214000300013Q00202F0004000200082Q004A0003000200020026480003004C000100040004283Q004C0001001214000300053Q00202F0004000200082Q0024000500024Q002400066Q0046000700014Q00180003000700040006330003003D00013Q0004283Q003D00012Q0024000500014Q0024000600044Q004A0005000200020006330005003D00013Q0004283Q003D00012Q0020000400023Q001214000500053Q00202F0006000200082Q0024000700024Q002400086Q00180005000800062Q0024000400064Q0024000300053Q0006330003004C00013Q0004283Q004C00012Q0024000500014Q0024000600044Q004A0005000200020006330005004C00013Q0004283Q004C00012Q0020000400023Q001214000300013Q001214000400094Q004A0003000200020026480003006C0001000A0004283Q006C0001001214000300013Q001214000400093Q00202F00040004000B2Q004A0003000200020026480003006C000100040004283Q006C0001001214000300053Q001214000400093Q00202F00040004000B2Q001700053Q00020010040005000C3Q00301D0005000D000E2Q00180003000500040006330003006C00013Q0004283Q006C00010012140005000F4Q0024000600044Q004A0005000200020026480005006C0001000A0004283Q006C00012Q0024000500013Q00202F0006000400102Q004A0005000200020006330005006C00013Q0004283Q006C000100202F0005000400102Q0020000500023Q001214000300013Q0012140004000B4Q004A00030002000200264800030083000100040004283Q00830001001214000300053Q00060A00040001000100012Q00218Q00070003000200040006330003008300013Q0004283Q008300010012140005000F4Q0024000600044Q004A000500020002002648000500830001000A0004283Q008300012Q0024000500013Q00202F0006000400102Q004A0005000200020006330005008300013Q0004283Q0083000100202F0005000400102Q0020000500023Q001214000300013Q001214000400114Q004A0003000200020026480003009C000100040004283Q009C0001001214000300053Q001214000400114Q001700053Q00020010040005000C3Q00301D0005000D000E2Q00180003000500040006330003009C00013Q0004283Q009C00010012140005000F4Q0024000600044Q004A0005000200020026480005009C0001000A0004283Q009C00012Q0024000500013Q00202F0006000400102Q004A0005000200020006330005009C00013Q0004283Q009C000100202F0005000400102Q0020000500024Q003F000300034Q0020000300024Q00013Q00013Q00023Q00033Q0003043Q007479706503063Q00737472696E67034Q00010B3Q001214000100014Q002400026Q004A00010002000200264800010007000100020004283Q000700010026483Q0008000100030004283Q000800012Q004B00016Q0046000100014Q0020000100024Q00013Q00017Q00043Q0003073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455400083Q0012143Q00014Q001700013Q00022Q000800025Q00100400010002000200301D0001000300042Q00433Q00014Q00168Q00013Q00017Q00083Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q0008402Q033Q00EFBBBF026Q00104001143Q001214000100014Q002400026Q004A00010002000200264800010007000100020004283Q000700010026483Q0008000100030004283Q000800012Q00203Q00023Q00204E00013Q0004001205000300053Q001205000400064Q002300010004000200264800010012000100070004283Q0012000100204E00013Q0004001205000300084Q0043000100034Q001600016Q00203Q00024Q00013Q00017Q000D3Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q006E4003053Q006C6F77657203043Q0066696E6403093Q003C21646F63747970650003053Q003C68746D6C030E3Q003430343A206E6F7420666F756E64030D3Q00343034206E6F7420666F756E64012F3Q001214000100014Q002400026Q004A00010002000200264800010007000100020004283Q000700010026483Q0009000100030004283Q000900012Q0046000100014Q0020000100023Q00204E00013Q0004001205000300053Q001205000400064Q002300010004000200204E0001000100072Q004A00010002000200204E000200010008001205000400093Q001205000500054Q0046000600014Q00230002000600020026480002002C0001000A0004283Q002C000100204E0002000100080012050004000B3Q001205000500054Q0046000600014Q00230002000600020026480002002C0001000A0004283Q002C000100204E0002000100080012050004000C3Q001205000500054Q0046000600014Q00230002000600020026480002002C0001000A0004283Q002C000100204E0002000100080012050004000D3Q001205000500054Q0046000600014Q00230002000600020026480002002C0001000A0004283Q002C00012Q004B00026Q0046000200014Q0020000200024Q00013Q00017Q00053Q00030A3Q00682Q74705F652Q726F7203043Q007479706503063Q00737472696E6703093Q00742Q6F5F736D612Q6C03023Q006F6B021F4Q000800026Q0024000300014Q004A0002000200022Q0024000100024Q0008000200014Q0024000300014Q004A0002000200020006330002000D00013Q0004283Q000D00012Q004600026Q003F000300033Q001205000400014Q002B000200023Q001214000200024Q0024000300014Q004A00020002000200264800020016000100030004283Q001600012Q004C000200014Q0008000300023Q00063A0002001A000100030004283Q001A00012Q004600026Q003F000300033Q001205000400044Q002B000200024Q0046000200014Q0024000300013Q001205000400054Q002B000200024Q00013Q00017Q00133Q00034Q00028Q00030B3Q006E6F5F726573706F6E736503063Q006970616972732Q033Q003F763D03043Q007479706503063Q00737472696E6703063Q0072656A65637403053Q007072696E7403113Q005B5343525D20646F776E6C6F616465642003023Q00202803083Q00746F737472696E67030D3Q00206279746573292066726F6D2003053Q00652Q726F72031D3Q005B5343525D20D09DD0B520D181D0BAD0B0D187D0B0D0BBD181D18F3A20030A3Q0020286C6F61646572207603063Q002C207768793D03063Q002C206C656E3D03063Q002C2075726C3D01424Q000800016Q0027000100010002001205000200013Q001205000300023Q001205000400033Q001214000500044Q0008000600014Q00070005000200070004283Q003000012Q0024000A00094Q0024000B5Q001205000C00054Q0024000D00014Q0037000A000A000D2Q00240002000A4Q0008000B00024Q0024000C000A4Q004A000B00020002001214000C00064Q0024000D000B4Q004A000C00020002002648000C001A000100070004283Q001A00012Q004C000C000B3Q0006150003001B0001000C0004283Q001B0001001205000300024Q0008000C00034Q0024000D6Q0024000E000B4Q0018000C000E000E000615000400220001000E0004283Q00220001001205000400083Q000633000C003000013Q0004283Q00300001001214000F00093Q0012050010000A4Q002400115Q0012050012000B3Q0012140013000C4Q004C0014000D4Q004A0013000200020012050014000D4Q0024001500094Q00370010001000152Q0019000F000200012Q0020000D00023Q00063B00050009000100020004283Q000900010012140005000E3Q0012050006000F4Q002400075Q001205000800104Q0008000900043Q001205000A00114Q0024000B00043Q001205000C00123Q001214000D000C4Q0024000E00034Q004A000D00020002001205000E00134Q0024000F00024Q003700060006000F2Q00190005000200012Q00013Q00017Q00", GetFEnv(), ...);
