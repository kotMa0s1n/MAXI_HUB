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
										local A = Inst[2];
										local B = Stk[Inst[3]];
										Stk[A + 1] = B;
										Stk[A] = B[Inst[4]];
									else
										local A = Inst[2];
										Stk[A](Stk[A + 1]);
									end
								elseif (Enum == 2) then
									Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
								elseif Stk[Inst[2]] then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum <= 5) then
								if (Enum > 4) then
									VIP = Inst[3];
								else
									Stk[Inst[2]] = Inst[3] ~= 0;
									VIP = VIP + 1;
								end
							elseif (Enum <= 6) then
								Stk[Inst[2]][Inst[3]] = Inst[4];
							elseif (Enum > 7) then
								do
									return;
								end
							else
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
							end
						elseif (Enum <= 13) then
							if (Enum <= 10) then
								if (Enum > 9) then
									Stk[Inst[2]] = Stk[Inst[3]];
								else
									local A = Inst[2];
									local B = Stk[Inst[3]];
									Stk[A + 1] = B;
									Stk[A] = B[Inst[4]];
								end
							elseif (Enum <= 11) then
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif (Enum > 12) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 15) then
							if (Enum > 14) then
								if (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
							end
						elseif (Enum <= 16) then
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 17) then
							Stk[Inst[2]] = Inst[3];
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
								if (Mvm[1] == 32) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						end
					elseif (Enum <= 27) then
						if (Enum <= 22) then
							if (Enum <= 20) then
								if (Enum == 19) then
									Stk[Inst[2]]();
								else
									do
										return Stk[Inst[2]];
									end
								end
							elseif (Enum == 21) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								Stk[Inst[2]] = Upvalues[Inst[3]];
							end
						elseif (Enum <= 24) then
							if (Enum > 23) then
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
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						elseif (Enum <= 25) then
							Stk[Inst[2]] = Env[Inst[3]];
						elseif (Enum == 26) then
							local A = Inst[2];
							do
								return Unpack(Stk, A, A + Inst[3]);
							end
						else
							Stk[Inst[2]] = Env[Inst[3]];
						end
					elseif (Enum <= 32) then
						if (Enum <= 29) then
							if (Enum == 28) then
								Stk[Inst[2]] = {};
							else
								Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
							end
						elseif (Enum <= 30) then
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						elseif (Enum == 31) then
							local A = Inst[2];
							local Results = {Stk[A](Stk[A + 1])};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]];
						end
					elseif (Enum <= 34) then
						if (Enum == 33) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						else
							local A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						end
					elseif (Enum <= 35) then
						Stk[Inst[2]] = Inst[3];
					elseif (Enum > 36) then
						Stk[Inst[2]]();
					else
						Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
					end
				elseif (Enum <= 56) then
					if (Enum <= 46) then
						if (Enum <= 41) then
							if (Enum <= 39) then
								if (Enum > 38) then
									do
										return Stk[Inst[2]];
									end
								elseif (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							elseif (Enum > 40) then
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							else
								local A = Inst[2];
								local Results = {Stk[A](Stk[A + 1])};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							end
						elseif (Enum <= 43) then
							if (Enum == 42) then
								Stk[Inst[2]] = Inst[3] ~= 0;
							else
								Stk[Inst[2]] = Inst[3] ~= 0;
							end
						elseif (Enum <= 44) then
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Top));
						elseif (Enum == 45) then
							local A = Inst[2];
							local T = Stk[A];
							for Idx = A + 1, Inst[3] do
								Insert(T, Stk[Idx]);
							end
						else
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						end
					elseif (Enum <= 51) then
						if (Enum <= 48) then
							if (Enum == 47) then
								local A = Inst[2];
								Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
							elseif Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum <= 49) then
							local A = Inst[2];
							local Results, Limit = _R(Stk[A](Stk[A + 1]));
							Top = (Limit + A) - 1;
							local Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						elseif (Enum > 50) then
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
								if (Mvm[1] == 32) then
									Indexes[Idx - 1] = {Stk,Mvm[3]};
								else
									Indexes[Idx - 1] = {Upvalues,Mvm[3]};
								end
								Lupvals[#Lupvals + 1] = Indexes;
							end
							Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
						elseif not Stk[Inst[2]] then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 53) then
						if (Enum > 52) then
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						elseif (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum <= 54) then
						Stk[Inst[2]][Inst[3]] = Inst[4];
					elseif (Enum > 55) then
						Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
					else
						local A = Inst[2];
						do
							return Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					end
				elseif (Enum <= 65) then
					if (Enum <= 60) then
						if (Enum <= 58) then
							if (Enum > 57) then
								local A = Inst[2];
								Stk[A] = Stk[A]();
							else
								Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
							end
						elseif (Enum == 59) then
							local A = Inst[2];
							Stk[A](Stk[A + 1]);
						else
							Stk[Inst[2]] = {};
						end
					elseif (Enum <= 62) then
						if (Enum > 61) then
							local A = Inst[2];
							local T = Stk[A];
							local B = Inst[3];
							for Idx = 1, B do
								T[Idx] = Stk[A + Idx];
							end
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
					elseif (Enum <= 63) then
						do
							return;
						end
					elseif (Enum > 64) then
						local B = Inst[3];
						local K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
					else
						local B = Inst[3];
						local K = Stk[B];
						for Idx = B + 1, Inst[4] do
							K = K .. Stk[Idx];
						end
						Stk[Inst[2]] = K;
					end
				elseif (Enum <= 70) then
					if (Enum <= 67) then
						if (Enum > 66) then
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						else
							local A = Inst[2];
							do
								return Unpack(Stk, A, Top);
							end
						end
					elseif (Enum <= 68) then
						if (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					elseif (Enum > 69) then
						local A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Top));
					else
						local A = Inst[2];
						Stk[A] = Stk[A](Stk[A + 1]);
					end
				elseif (Enum <= 72) then
					if (Enum > 71) then
						for Idx = Inst[2], Inst[3] do
							Stk[Idx] = nil;
						end
					else
						local A = Inst[2];
						Stk[A] = Stk[A]();
					end
				elseif (Enum <= 73) then
					local A = Inst[2];
					local T = Stk[A];
					local B = Inst[3];
					for Idx = 1, B do
						T[Idx] = Stk[A + Idx];
					end
				elseif (Enum == 74) then
					local A = Inst[2];
					do
						return Stk[A], Stk[A + 1];
					end
				else
					local A = Inst[2];
					do
						return Unpack(Stk, A, Top);
					end
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!1E3Q002Q033Q00312E3103453Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F656C2D7061736F2D62722F033F3Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F656C2D7061736F2D62722F030C3Q006C61756E636865722E6C7561030D3Q00657062722D636F72652E6C7561030A3Q00656C2D7061736F2D627203063Q00747970656F6603093Q00777269746566696C6503083Q0066756E6374696F6E03083Q007265616466696C6503063Q00697366696C6503053Q00652Q726F7203373Q005B455042525D20D09DD183D0B6D0B5D0BD206578656375746F7220D18120777269746566696C652F7265616466696C652F697366696C6503103Q00455042525F4F2Q66696369616C526177026Q00F03F030E3Q00455042525F4C6F6164657255726C030A3Q006C6F616465722E6C756103123Q00455042525F4C6F6164657256657273696F6E030D3Q00455042525F5265706F4F6E6C792Q01030E3Q004D617869487562536B69704B6579030A3Q006D616B65666F6C64657203053Q007063612Q6C03063Q0069706169727303013Q002F030D3Q002F6C61756E636865722E6C7561030A3Q006C6F6164737472696E67030D3Q00406C61756E636865722E6C756103113Q005B455042525D206C61756E636865723A2003083Q00746F737472696E6700603Q002Q123Q00014Q003C000100023Q002Q12000200023Q002Q12000300034Q003E0001000200012Q003C000200023Q002Q12000300043Q002Q12000400054Q003E000200020001002Q12000300063Q00023800045Q000238000500013Q000238000600023Q000238000700033Q00063300080004000100012Q00203Q00073Q00063300090005000100052Q00203Q00054Q00203Q00014Q00203Q00064Q00203Q00084Q00207Q00121B000A00073Q00121B000B00084Q0045000A00020002002634000A0025000100090004053Q0025000100121B000A00073Q00121B000B000A4Q0045000A00020002002634000A0025000100090004053Q0025000100121B000A00073Q00121B000B000B4Q0045000A0002000200260F000A0028000100090004053Q0028000100121B000A000C3Q002Q12000B000D4Q0001000A000200012Q000A000A00044Q0047000A00010002002002000B0001000F00102E000A000E000B002002000B0001000F002Q12000C00114Q0040000B000B000C00102E000A0010000B00102E000A00123Q003036000A00130014003036000A0015001400121B000B00073Q00121B000C00164Q0045000B00020002002634000B003C000100090004053Q003C000100121B000B00173Q00121B000C00164Q000A000D00034Q000B000B000D000100121B000B00184Q000A000C00024Q0028000B0002000D0004053Q0049000100121B001000084Q000A001100033Q002Q12001200194Q000A0013000F4Q00400011001100132Q000A001200094Q000A0013000F4Q0031001200134Q002C00103Q0001000618000B0040000100020004053Q0040000100121B000B000A4Q000A000C00033Q002Q12000D001A4Q0040000C000C000D2Q0045000B0002000200121B000C001B4Q000A000D000B3Q002Q12000E001C4Q0015000C000E000D000632000C005D000100010004053Q005D000100121B000E000C3Q002Q12000F001D3Q00121B0010001E4Q000A0011000D4Q00450010000200022Q0040000F000F00102Q0001000E000200012Q000A000E000C4Q0025000E000100012Q003F3Q00013Q00063Q00043Q0003063Q00747970656F6603073Q0067657467656E7603083Q0066756E6374696F6E03023Q005F47000C3Q00121B3Q00013Q00121B000100024Q00453Q000200020026343Q0009000100030004053Q0009000100121B3Q00024Q00473Q000100020006323Q000A000100010004053Q000A000100121B3Q00044Q00273Q00024Q003F3Q00017Q000A3Q0003063Q00747970656F6603023Q006F7303053Q007461626C6503043Q0074696D65028Q0003043Q006D61746803063Q0072616E646F6D025Q00408F40024Q008087C34003083Q00746F737472696E6700293Q00121B3Q00013Q00121B000100024Q00453Q000200020026343Q000E000100030004053Q000E000100121B3Q00023Q0020025Q00040006033Q000E00013Q0004053Q000E000100121B3Q00023Q0020025Q00042Q00473Q000100020006323Q000F000100010004053Q000F0001002Q123Q00053Q00121B000100013Q00121B000200064Q00450001000200020026340001001F000100030004053Q001F000100121B000100063Q0020020001000100070006030001001F00013Q0004053Q001F000100121B000100063Q002002000100010007002Q12000200083Q002Q12000300094Q002F00010003000200063200010020000100010004053Q00200001002Q12000100053Q00121B0002000A4Q000A00036Q004500020002000200121B0003000A4Q000A000400014Q00450003000200022Q00400002000200032Q0027000200024Q003F3Q00017Q000B3Q0003063Q00747970656F6603043Q0067616D6503073Q00482Q747047657403083Q0066756E6374696F6E03053Q007063612Q6C03043Q007479706503063Q00737472696E67034Q0003073Q007265717565737403053Q007461626C6503043Q00426F647901443Q00121B000100013Q00121B000200023Q0020020002000200032Q004500010002000200263400010027000100040004053Q0027000100121B000100053Q00121B000200023Q0020020002000200032Q000A00036Q002B000400014Q00150001000400020006030001001600013Q0004053Q0016000100121B000300064Q000A000400024Q004500030002000200263400030016000100070004053Q0016000100260F00020016000100080004053Q001600012Q0027000200023Q00121B000300053Q00121B000400023Q0020020004000400032Q000A00056Q00150003000500042Q000A000200044Q000A000100033Q0006030001002700013Q0004053Q0027000100121B000300064Q000A000400024Q004500030002000200263400030027000100070004053Q0027000100260F00020027000100080004053Q002700012Q0027000200023Q00121B000100013Q00121B000200094Q004500010002000200263400010041000100040004053Q0041000100121B000100053Q00063300023Q000100012Q00208Q00280001000200020006030001004100013Q0004053Q0041000100121B000300064Q000A000400024Q0045000300020002002634000300410001000A0004053Q0041000100121B000300063Q00200200040002000B2Q004500030002000200263400030041000100070004053Q0041000100200200030002000B00260F00030041000100080004053Q0041000100200200030002000B2Q0027000300024Q0048000100014Q0027000100024Q003F3Q00013Q00013Q00043Q0003073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455400083Q00121B3Q00014Q003C00013Q00022Q002100025Q00102E0001000200020030360001000300042Q00373Q00014Q00428Q003F3Q00017Q00083Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q0008402Q033Q00EFBBBF026Q00104001143Q00121B000100014Q000A00026Q004500010002000200263400010007000100020004053Q000700010026343Q0008000100030004053Q000800012Q00273Q00023Q00202Q00013Q0004002Q12000300053Q002Q12000400064Q002F00010004000200263400010012000100070004053Q0012000100202Q00013Q0004002Q12000300084Q0037000100034Q004200016Q00273Q00024Q003F3Q00017Q00063Q0003043Q007479706503063Q00737472696E67034Q00030A3Q006C6F6164737472696E6703013Q004000021A4Q002100026Q000A000300014Q00450002000200022Q000A000100023Q00121B000200014Q000A000300014Q00450002000200020026340002000B000100020004053Q000B00010026340001000D000100030004053Q000D00012Q002B00026Q0027000200023Q00121B000200044Q000A000300013Q002Q12000400054Q000A00056Q00400004000400052Q002F00020004000200263400020016000100060004053Q001600012Q000E00026Q002B000200014Q000A000300014Q004A000200034Q003F3Q00017Q00063Q0003063Q006970616972732Q033Q003F763D03053Q00652Q726F72031E3Q005B455042525D20D09DD0B520D181D0BAD0B0D187D0B0D0BBD181D18F3A20030A3Q0020286C6F61646572207603013Q002901204Q002100016Q004700010001000200121B000200014Q0021000300014Q00280002000200040004053Q001500012Q000A000700064Q000A00085Q002Q12000900024Q000A000A00014Q004000070007000A2Q0021000800024Q000A000900074Q00450008000200022Q0021000900034Q000A000A6Q000A000B00084Q00150009000B000A0006030009001500013Q0004053Q001500012Q0027000A00023Q00061800020006000100020004053Q0006000100121B000200033Q002Q12000300044Q000A00045Q002Q12000500054Q0021000600043Q002Q12000700064Q00400003000300072Q00010002000200012Q003F3Q00017Q00", GetFEnv(), ...);
