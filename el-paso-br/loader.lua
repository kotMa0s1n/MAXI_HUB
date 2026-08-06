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
				if (Enum <= 37) then
					if (Enum <= 18) then
						if (Enum <= 8) then
							if (Enum <= 3) then
								if (Enum <= 1) then
									if (Enum == 0) then
										Stk[Inst[2]][Inst[3]] = Inst[4];
									else
										Stk[Inst[2]] = Env[Inst[3]];
									end
								elseif (Enum > 2) then
									local A = Inst[2];
									Stk[A](Unpack(Stk, A + 1, Top));
								else
									Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
								end
							elseif (Enum <= 5) then
								if (Enum > 4) then
									Stk[Inst[2]] = Inst[3] ~= 0;
								else
									do
										return;
									end
								end
							elseif (Enum <= 6) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif (Enum == 7) then
								VIP = Inst[3];
							elseif Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 13) then
							if (Enum <= 10) then
								if (Enum == 9) then
									do
										return Stk[Inst[2]];
									end
								else
									local A = Inst[2];
									local T = Stk[A];
									for Idx = A + 1, Inst[3] do
										Insert(T, Stk[Idx]);
									end
								end
							elseif (Enum <= 11) then
								local A = Inst[2];
								local T = Stk[A];
								local B = Inst[3];
								for Idx = 1, B do
									T[Idx] = Stk[A + Idx];
								end
							elseif (Enum == 12) then
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
						elseif (Enum <= 15) then
							if (Enum > 14) then
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
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
							end
						elseif (Enum <= 16) then
							local B = Inst[3];
							local K = Stk[B];
							for Idx = B + 1, Inst[4] do
								K = K .. Stk[Idx];
							end
							Stk[Inst[2]] = K;
						elseif (Enum > 17) then
							if (Stk[Inst[2]] == Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
						end
					elseif (Enum <= 27) then
						if (Enum <= 22) then
							if (Enum <= 20) then
								if (Enum == 19) then
									local A = Inst[2];
									do
										return Unpack(Stk, A, Top);
									end
								else
									do
										return;
									end
								end
							elseif (Enum > 21) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Top));
							else
								do
									return Stk[Inst[2]];
								end
							end
						elseif (Enum <= 24) then
							if (Enum > 23) then
								for Idx = Inst[2], Inst[3] do
									Stk[Idx] = nil;
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
									if (Mvm[1] == 56) then
										Indexes[Idx - 1] = {Stk,Mvm[3]};
									else
										Indexes[Idx - 1] = {Upvalues,Mvm[3]};
									end
									Lupvals[#Lupvals + 1] = Indexes;
								end
								Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
							end
						elseif (Enum <= 25) then
							local A = Inst[2];
							do
								return Unpack(Stk, A, A + Inst[3]);
							end
						elseif (Enum > 26) then
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
								if (Mvm[1] == 56) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						else
							local A = Inst[2];
							do
								return Unpack(Stk, A, Top);
							end
						end
					elseif (Enum <= 32) then
						if (Enum <= 29) then
							if (Enum > 28) then
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
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 30) then
							if (Stk[Inst[2]] ~= Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 31) then
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						elseif (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 34) then
						if (Enum == 33) then
							VIP = Inst[3];
						else
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						end
					elseif (Enum <= 35) then
						local B = Inst[3];
						local K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
					elseif (Enum > 36) then
						if not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					else
						Stk[Inst[2]][Inst[3]] = Inst[4];
					end
				elseif (Enum <= 56) then
					if (Enum <= 46) then
						if (Enum <= 41) then
							if (Enum <= 39) then
								if (Enum == 38) then
									local A = Inst[2];
									local B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
								else
									Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
								end
							elseif (Enum == 40) then
								local A = Inst[2];
								Stk[A] = Stk[A]();
							else
								local A = Inst[2];
								local Results, Limit = _R(Stk[A](Stk[A + 1]));
								Top = (Limit + A) - 1;
								local Edx = 0;
								for Idx = A, Top do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 43) then
							if (Enum > 42) then
								local A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
							else
								Stk[Inst[2]] = Inst[3];
							end
						elseif (Enum <= 44) then
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						elseif (Enum == 45) then
							if (Stk[Inst[2]] ~= Inst[4]) then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Upvalues[Inst[3]];
						end
					elseif (Enum <= 51) then
						if (Enum <= 48) then
							if (Enum == 47) then
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							else
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							end
						elseif (Enum <= 49) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						elseif (Enum == 50) then
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							local A = Inst[2];
							local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						end
					elseif (Enum <= 53) then
						if (Enum == 52) then
							local A = Inst[2];
							local B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
						else
							local A = Inst[2];
							local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						end
					elseif (Enum <= 54) then
						local A = Inst[2];
						local T = Stk[A];
						local B = Inst[3];
						for Idx = 1, B do
							T[Idx] = Stk[A + Idx];
						end
					elseif (Enum > 55) then
						Stk[Inst[2]] = Stk[Inst[3]];
					else
						local A = Inst[2];
						local Results, Limit = _R(Stk[A](Stk[A + 1]));
						Top = (Limit + A) - 1;
						local Edx = 0;
						for Idx = A, Top do
							Edx = Edx + 1;
							Stk[Idx] = Results[Edx];
						end
					end
				elseif (Enum <= 65) then
					if (Enum <= 60) then
						if (Enum <= 58) then
							if (Enum > 57) then
								Stk[Inst[2]] = Inst[3] ~= 0;
							else
								local A = Inst[2];
								Stk[A] = Stk[A]();
							end
						elseif (Enum == 59) then
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
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
					elseif (Enum <= 62) then
						if (Enum == 61) then
							local A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						else
							Stk[Inst[2]] = {};
						end
					elseif (Enum <= 63) then
						Stk[Inst[2]] = Inst[3] ~= 0;
						VIP = VIP + 1;
					elseif (Enum == 64) then
						local A = Inst[2];
						Stk[A](Stk[A + 1]);
					else
						local A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
					end
				elseif (Enum <= 70) then
					if (Enum <= 67) then
						if (Enum == 66) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						else
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						end
					elseif (Enum <= 68) then
						for Idx = Inst[2], Inst[3] do
							Stk[Idx] = nil;
						end
					elseif (Enum == 69) then
						Stk[Inst[2]]();
					else
						local A = Inst[2];
						do
							return Stk[A], Stk[A + 1];
						end
					end
				elseif (Enum <= 72) then
					if (Enum == 71) then
						Stk[Inst[2]]();
					elseif not Stk[Inst[2]] then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 73) then
					Stk[Inst[2]] = {};
				elseif (Enum > 74) then
					Stk[Inst[2]] = Inst[3];
				else
					Stk[Inst[2]] = Env[Inst[3]];
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!1E3Q002Q033Q00312E3103453Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F656C2D7061736F2D62722F033F3Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F656C2D7061736F2D62722F030C3Q006C61756E636865722E6C7561030D3Q00657062722D636F72652E6C7561030A3Q00656C2D7061736F2D627203063Q00747970656F6603093Q00777269746566696C6503083Q0066756E6374696F6E03083Q007265616466696C6503063Q00697366696C6503053Q00652Q726F7203373Q005B455042525D20D09DD183D0B6D0B5D0BD206578656375746F7220D18120777269746566696C652F7265616466696C652F697366696C6503103Q00455042525F4F2Q66696369616C526177026Q00F03F030E3Q00455042525F4C6F6164657255726C030A3Q006C6F616465722E6C756103123Q00455042525F4C6F6164657256657273696F6E030D3Q00455042525F5265706F4F6E6C792Q01030E3Q004D617869487562536B69704B6579030A3Q006D616B65666F6C64657203053Q007063612Q6C03063Q0069706169727303013Q002F030D3Q002F6C61756E636865722E6C7561030A3Q006C6F6164737472696E67030D3Q00406C61756E636865722E6C756103113Q005B455042525D206C61756E636865723A2003083Q00746F737472696E6700603Q00124B3Q00014Q003E000100023Q00124B000200023Q00124B000300034Q000B0001000200012Q003E000200023Q00124B000300043Q00124B000400054Q000B00020002000100124B000300063Q002Q0200045Q002Q02000500013Q002Q02000600023Q002Q02000700033Q00061700080004000100012Q00383Q00073Q00061700090005000100052Q00383Q00054Q00383Q00014Q00383Q00064Q00383Q00084Q00387Q00124A000A00073Q00124A000B00084Q0011000A0002000200261F000A0025000100090004213Q0025000100124A000A00073Q00124A000B000A4Q0011000A0002000200261F000A0025000100090004213Q0025000100124A000A00073Q00124A000B000B4Q0011000A0002000200262D000A0028000100090004213Q0028000100124A000A000C3Q00124B000B000D4Q000C000A000200012Q001C000A00044Q0039000A00010002002030000B0001000F001022000A000E000B002030000B0001000F00124B000C00114Q0023000B000B000C001022000A0010000B001022000A00123Q003024000A00130014003024000A0015001400124A000B00073Q00124A000C00164Q0011000B0002000200261F000B003C000100090004213Q003C000100124A000B00173Q00124A000C00164Q001C000D00034Q0042000B000D000100124A000B00184Q001C000C00024Q003C000B0002000D0004213Q0049000100124A001000084Q001C001100033Q00124B001200194Q001C0013000F4Q00230011001100132Q001C001200094Q001C0013000F4Q0037001200134Q000300103Q000100060F000B0040000100020004213Q0040000100124A000B000A4Q001C000C00033Q00124B000D001A4Q0023000C000C000D2Q0011000B0002000200124A000C001B4Q001C000D000B3Q00124B000E001C4Q0033000C000E000D000648000C005D000100010004213Q005D000100124A000E000C3Q00124B000F001D3Q00124A0010001E4Q001C0011000D4Q00110010000200022Q0023000F000F00102Q000C000E000200012Q001C000E000C4Q0045000E000100012Q00043Q00013Q00063Q00043Q0003063Q00747970656F6603073Q0067657467656E7603083Q0066756E6374696F6E03023Q005F47000C3Q00124A3Q00013Q00124A000100024Q00113Q0002000200261F3Q0009000100030004213Q0009000100124A3Q00024Q00393Q000100020006483Q000A000100010004213Q000A000100124A3Q00044Q00153Q00024Q00043Q00017Q000A3Q0003063Q00747970656F6603023Q006F7303053Q007461626C6503043Q0074696D65028Q0003043Q006D61746803063Q0072616E646F6D025Q00408F40024Q008087C34003083Q00746F737472696E6700293Q00124A3Q00013Q00124A000100024Q00113Q0002000200261F3Q000E000100030004213Q000E000100124A3Q00023Q0020305Q00040006083Q000E00013Q0004213Q000E000100124A3Q00023Q0020305Q00042Q00393Q000100020006483Q000F000100010004213Q000F000100124B3Q00053Q00124A000100013Q00124A000200064Q001100010002000200261F0001001F000100030004213Q001F000100124A000100063Q0020300001000100070006080001001F00013Q0004213Q001F000100124A000100063Q00203000010001000700124B000200083Q00124B000300094Q002F00010003000200064800010020000100010004213Q0020000100124B000100053Q00124A0002000A4Q001C00036Q001100020002000200124A0003000A4Q001C000400014Q00110003000200022Q00230002000200032Q0015000200024Q00043Q00017Q000B3Q0003063Q00747970656F6603043Q0067616D6503073Q00482Q747047657403083Q0066756E6374696F6E03053Q007063612Q6C03043Q007479706503063Q00737472696E67034Q0003073Q007265717565737403053Q007461626C6503043Q00426F647901443Q00124A000100013Q00124A000200023Q0020300002000200032Q001100010002000200261F00010027000100040004213Q0027000100124A000100053Q00124A000200023Q0020300002000200032Q001C00036Q0005000400014Q00330001000400020006080001001600013Q0004213Q0016000100124A000300064Q001C000400024Q001100030002000200261F00030016000100070004213Q0016000100262D00020016000100080004213Q001600012Q0015000200023Q00124A000300053Q00124A000400023Q0020300004000400032Q001C00056Q00330003000500042Q001C000200044Q001C000100033Q0006080001002700013Q0004213Q0027000100124A000300064Q001C000400024Q001100030002000200261F00030027000100070004213Q0027000100262D00020027000100080004213Q002700012Q0015000200023Q00124A000100013Q00124A000200094Q001100010002000200261F00010041000100040004213Q0041000100124A000100053Q00061700023Q000100012Q00388Q003C0001000200020006080001004100013Q0004213Q0041000100124A000300064Q001C000400024Q001100030002000200261F000300410001000A0004213Q0041000100124A000300063Q00203000040002000B2Q001100030002000200261F00030041000100070004213Q0041000100203000030002000B00262D00030041000100080004213Q0041000100203000030002000B2Q0015000300024Q0044000100014Q0015000100024Q00043Q00013Q00013Q00043Q0003073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455400083Q00124A3Q00014Q003E00013Q00022Q002E00025Q0010220001000200020030240001000300042Q002B3Q00014Q00138Q00043Q00017Q00083Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q0008402Q033Q00EFBBBF026Q00104001143Q00124A000100014Q001C00026Q001100010002000200261F00010007000100020004213Q0007000100261F3Q0008000100030004213Q000800012Q00153Q00023Q00203400013Q000400124B000300053Q00124B000400064Q002F00010004000200261F00010012000100070004213Q0012000100203400013Q000400124B000300084Q002B000100034Q001300016Q00153Q00024Q00043Q00017Q00063Q0003043Q007479706503063Q00737472696E67034Q00030A3Q006C6F6164737472696E6703013Q004000021A4Q002E00026Q001C000300014Q00110002000200022Q001C000100023Q00124A000200014Q001C000300014Q001100020002000200261F0002000B000100020004213Q000B000100261F0001000D000100030004213Q000D00012Q000500026Q0015000200023Q00124A000200044Q001C000300013Q00124B000400054Q001C00056Q00230004000400052Q002F00020004000200261F00020016000100060004213Q001600012Q000E00026Q0005000200014Q001C000300014Q0043000200034Q00043Q00017Q00063Q0003063Q006970616972732Q033Q003F763D03053Q00652Q726F72031E3Q005B455042525D20D09DD0B520D181D0BAD0B0D187D0B0D0BBD181D18F3A20030A3Q0020286C6F61646572207603013Q002901204Q002E00016Q003900010001000200124A000200014Q002E000300014Q003C0002000200040004213Q001500012Q001C000700064Q001C00085Q00124B000900024Q001C000A00014Q002300070007000A2Q002E000800024Q001C000900074Q00110008000200022Q002E000900034Q001C000A6Q001C000B00084Q00330009000B000A0006080009001500013Q0004213Q001500012Q0015000A00023Q00060F00020006000100020004213Q0006000100124A000200033Q00124B000300044Q001C00045Q00124B000500054Q002E000600043Q00124B000700064Q00230003000300072Q000C0002000200012Q00043Q00017Q00", GetFEnv(), ...);
