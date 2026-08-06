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
									if (Enum > 0) then
										do
											return Stk[Inst[2]];
										end
									else
										local A = Inst[2];
										local T = Stk[A];
										local B = Inst[3];
										for Idx = 1, B do
											T[Idx] = Stk[A + Idx];
										end
									end
								elseif (Enum > 2) then
									Stk[Inst[2]] = Env[Inst[3]];
								else
									local A = Inst[2];
									local T = Stk[A];
									for Idx = A + 1, Inst[3] do
										Insert(T, Stk[Idx]);
									end
								end
							elseif (Enum <= 5) then
								if (Enum > 4) then
									local A = Inst[2];
									do
										return Stk[A], Stk[A + 1];
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
										if (Mvm[1] == 22) then
											Indexes[Idx - 1] = {Stk,Mvm[3]};
										else
											Indexes[Idx - 1] = {Upvalues,Mvm[3]};
										end
										Lupvals[#Lupvals + 1] = Indexes;
									end
									Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
								end
							elseif (Enum <= 6) then
								Stk[Inst[2]]();
							elseif (Enum == 7) then
								local A = Inst[2];
								do
									return Stk[A](Unpack(Stk, A + 1, Inst[3]));
								end
							else
								local A = Inst[2];
								local B = Stk[Inst[3]];
								Stk[A + 1] = B;
								Stk[A] = B[Inst[4]];
							end
						elseif (Enum <= 13) then
							if (Enum <= 10) then
								if (Enum > 9) then
									do
										return;
									end
								else
									Stk[Inst[2]] = {};
								end
							elseif (Enum <= 11) then
								Stk[Inst[2]] = Inst[3] ~= 0;
								VIP = VIP + 1;
							elseif (Enum == 12) then
								Stk[Inst[2]] = Inst[3] ~= 0;
							else
								local A = Inst[2];
								Stk[A](Stk[A + 1]);
							end
						elseif (Enum <= 15) then
							if (Enum == 14) then
								Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
							else
								Stk[Inst[2]]();
							end
						elseif (Enum <= 16) then
							Stk[Inst[2]] = Inst[3] ~= 0;
						elseif (Enum == 17) then
							do
								return;
							end
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Stk[A + 1]);
						end
					elseif (Enum <= 27) then
						if (Enum <= 22) then
							if (Enum <= 20) then
								if (Enum == 19) then
									if Stk[Inst[2]] then
										VIP = VIP + 1;
									else
										VIP = Inst[3];
									end
								else
									Stk[Inst[2]][Inst[3]] = Inst[4];
								end
							elseif (Enum == 21) then
								if (Stk[Inst[2]] ~= Inst[4]) then
									VIP = VIP + 1;
								else
									VIP = Inst[3];
								end
							else
								Stk[Inst[2]] = Stk[Inst[3]];
							end
						elseif (Enum <= 24) then
							if (Enum == 23) then
								Stk[Inst[2]] = Stk[Inst[3]];
							else
								local A = Inst[2];
								Stk[A] = Stk[A]();
							end
						elseif (Enum <= 25) then
							local A = Inst[2];
							do
								return Unpack(Stk, A, A + Inst[3]);
							end
						elseif (Enum == 26) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						else
							local A = Inst[2];
							local Results = {Stk[A](Stk[A + 1])};
							local Edx = 0;
							for Idx = A, Inst[4] do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						end
					elseif (Enum <= 32) then
						if (Enum <= 29) then
							if (Enum > 28) then
								local A = Inst[2];
								local Results = {Stk[A](Unpack(Stk, A + 1, Inst[3]))};
								local Edx = 0;
								for Idx = A, Inst[4] do
									Edx = Edx + 1;
									Stk[Idx] = Results[Edx];
								end
							else
								local A = Inst[2];
								Stk[A](Unpack(Stk, A + 1, Top));
							end
						elseif (Enum <= 30) then
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 31) then
							local A = Inst[2];
							local Results, Limit = _R(Stk[A](Stk[A + 1]));
							Top = (Limit + A) - 1;
							local Edx = 0;
							for Idx = A, Top do
								Edx = Edx + 1;
								Stk[Idx] = Results[Edx];
							end
						else
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Top));
						end
					elseif (Enum <= 34) then
						if (Enum == 33) then
							local A = Inst[2];
							do
								return Stk[A](Unpack(Stk, A + 1, Inst[3]));
							end
						else
							local A = Inst[2];
							Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum <= 35) then
						Stk[Inst[2]][Inst[3]] = Inst[4];
					elseif (Enum == 36) then
						Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
					elseif (Stk[Inst[2]] == Inst[4]) then
						VIP = VIP + 1;
					else
						VIP = Inst[3];
					end
				elseif (Enum <= 56) then
					if (Enum <= 46) then
						if (Enum <= 41) then
							if (Enum <= 39) then
								if (Enum == 38) then
									VIP = Inst[3];
								else
									local B = Inst[3];
									local K = Stk[B];
									for Idx = B + 1, Inst[4] do
										K = K .. Stk[Idx];
									end
									Stk[Inst[2]] = K;
								end
							elseif (Enum == 40) then
								local A = Inst[2];
								Stk[A](Stk[A + 1]);
							else
								do
									return Stk[Inst[2]];
								end
							end
						elseif (Enum <= 43) then
							if (Enum > 42) then
								Stk[Inst[2]] = Inst[3];
							else
								local B = Inst[3];
								local K = Stk[B];
								for Idx = B + 1, Inst[4] do
									K = K .. Stk[Idx];
								end
								Stk[Inst[2]] = K;
							end
						elseif (Enum <= 44) then
							Stk[Inst[2]] = Wrap(Proto[Inst[3]], nil, Env);
						elseif (Enum == 45) then
							Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
						else
							local A = Inst[2];
							do
								return Unpack(Stk, A, Top);
							end
						end
					elseif (Enum <= 51) then
						if (Enum <= 48) then
							if (Enum == 47) then
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
									if (Mvm[1] == 22) then
										Indexes[Idx - 1] = {Stk,Mvm[3]};
									else
										Indexes[Idx - 1] = {Upvalues,Mvm[3]};
									end
									Lupvals[#Lupvals + 1] = Indexes;
								end
								Stk[Inst[2]] = Wrap(NewProto, NewUvals, Env);
							else
								Stk[Inst[2]] = {};
							end
						elseif (Enum <= 49) then
							if Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						elseif (Enum > 50) then
							Stk[Inst[2]] = Env[Inst[3]];
						else
							local A = Inst[2];
							Stk[A] = Stk[A](Unpack(Stk, A + 1, Inst[3]));
						end
					elseif (Enum <= 53) then
						if (Enum == 52) then
							if not Stk[Inst[2]] then
								VIP = VIP + 1;
							else
								VIP = Inst[3];
							end
						else
							Stk[Inst[2]] = Inst[3] ~= 0;
							VIP = VIP + 1;
						end
					elseif (Enum <= 54) then
						Stk[Inst[2]][Inst[3]] = Stk[Inst[4]];
					elseif (Enum > 55) then
						if (Stk[Inst[2]] == Inst[4]) then
							VIP = VIP + 1;
						else
							VIP = Inst[3];
						end
					else
						for Idx = Inst[2], Inst[3] do
							Stk[Idx] = nil;
						end
					end
				elseif (Enum <= 65) then
					if (Enum <= 60) then
						if (Enum <= 58) then
							if (Enum == 57) then
								local A = Inst[2];
								Stk[A] = Stk[A](Stk[A + 1]);
							else
								local A = Inst[2];
								Stk[A] = Stk[A]();
							end
						elseif (Enum > 59) then
							local A = Inst[2];
							do
								return Stk[A], Stk[A + 1];
							end
						else
							Stk[Inst[2]] = Stk[Inst[3]][Inst[4]];
						end
					elseif (Enum <= 62) then
						if (Enum > 61) then
							Stk[Inst[2]] = Upvalues[Inst[3]];
						else
							local A = Inst[2];
							local B = Stk[Inst[3]];
							Stk[A + 1] = B;
							Stk[A] = B[Inst[4]];
						end
					elseif (Enum <= 63) then
						VIP = Inst[3];
					elseif (Enum == 64) then
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
				elseif (Enum <= 70) then
					if (Enum <= 67) then
						if (Enum == 66) then
							for Idx = Inst[2], Inst[3] do
								Stk[Idx] = nil;
							end
						else
							Stk[Inst[2]] = Inst[3];
						end
					elseif (Enum <= 68) then
						local A = Inst[2];
						Stk[A](Unpack(Stk, A + 1, Inst[3]));
					elseif (Enum > 69) then
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
						local T = Stk[A];
						local B = Inst[3];
						for Idx = 1, B do
							T[Idx] = Stk[A + Idx];
						end
					end
				elseif (Enum <= 72) then
					if (Enum == 71) then
						local A = Inst[2];
						do
							return Unpack(Stk, A, Top);
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
				elseif (Enum <= 73) then
					local A = Inst[2];
					local Results = {Stk[A](Stk[A + 1])};
					local Edx = 0;
					for Idx = A, Inst[4] do
						Edx = Edx + 1;
						Stk[Idx] = Results[Edx];
					end
				elseif (Enum == 74) then
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
				elseif (Stk[Inst[2]] ~= Inst[4]) then
					VIP = VIP + 1;
				else
					VIP = Inst[3];
				end
				VIP = VIP + 1;
			end
		end;
	end
	return Wrap(Deserialize(), {}, vmenv)(...);
end
return VMCall("LOL!233Q002Q033Q00312E31033E3Q00682Q7470733A2Q2F7261772E67697468756275736572636F6E74656E742E636F6D2F6B6F744D613073316E2F4D4158495F4855422F6D61696E2F7363722F03383Q00682Q7470733A2Q2F63646E2E6A7364656C6976722E6E65742F67682F6B6F744D613073316E2F4D4158495F485542406D61696E2F7363722F030C3Q006C61756E636865722E6C756103113Q007363722D622Q6F7473747261702E6C7561030D3Q007363722D6C6F6769632E6C7561030E3Q007363722D6C6F63616C652E6C7561030E3Q007363722D636F6E6669672E6C7561030F3Q006D6178692D6875622D75692E6C756103173Q0073746570666F72642D636F756E74792D7261696C77617903063Q00747970656F6603093Q00777269746566696C6503083Q0066756E6374696F6E03083Q007265616466696C6503063Q00697366696C6503053Q00652Q726F7203363Q005B5343525D20D09DD183D0B6D0B5D0BD206578656375746F7220D18120777269746566696C652F7265616466696C652F697366696C65030F3Q005343525F4F2Q66696369616C526177026Q00F03F030D3Q005343525F4C6F6164657255726C030A3Q006C6F616465722E6C756103113Q005343525F4C6F6164657256657273696F6E030C3Q005343525F5265706F4F6E6C792Q01030E3Q004D617869487562536B69704B657903113Q004D61786948756247616D65536372697074030A3Q006D616B65666F6C64657203053Q007063612Q6C03063Q0069706169727303013Q002F030D3Q002F6C61756E636865722E6C7561030A3Q006C6F6164737472696E67030D3Q00406C61756E636865722E6C756103103Q005B5343525D206C61756E636865723A2003083Q00746F737472696E6700653Q00122B3Q00014Q0030000100023Q00122B000200023Q00122B000300034Q00450001000200012Q0030000200063Q00122B000300043Q00122B000400053Q00122B000500063Q00122B000600073Q00122B000700083Q00122B000800094Q004500020006000100122B0003000A3Q00022C00045Q00022C000500013Q00022C000600023Q00022C000700033Q00060400080004000100012Q00163Q00073Q00060400090005000100052Q00163Q00054Q00163Q00014Q00163Q00064Q00163Q00084Q00167Q001233000A000B3Q001233000B000C4Q0012000A00020002002625000A00290001000D0004263Q00290001001233000A000B3Q001233000B000E4Q0012000A00020002002625000A00290001000D0004263Q00290001001233000A000B3Q001233000B000F4Q0012000A0002000200264B000A002C0001000D0004263Q002C0001001233000A00103Q00122B000B00114Q0028000A000200012Q0017000A00044Q003A000A00010002002024000B00010013001036000A0012000B002024000B0001001300122B000C00154Q002A000B000B000C001036000A0014000B001036000A00163Q003014000A00170018003014000A00190018003014000A001A0018001233000B000B3Q001233000C001B4Q0012000B00020002002625000B00410001000D0004263Q00410001001233000B001C3Q001233000C001B4Q0017000D00034Q0044000B000D0001001233000B001D4Q0017000C00024Q0049000B0002000D0004263Q004E00010012330010000C4Q0017001100033Q00122B0012001E4Q00170013000F4Q002A0011001100132Q0017001200094Q00170013000F4Q0020001200134Q001C00103Q000100064A000B0045000100020004263Q00450001001233000B000E4Q0017000C00033Q00122B000D001F4Q002A000C000C000D2Q0012000B00020002001233000C00204Q0017000D000B3Q00122B000E00214Q0041000C000E000D00061E000C0062000100010004263Q00620001001233000E00103Q00122B000F00223Q001233001000234Q00170011000D4Q00120010000200022Q002A000F000F00102Q0028000E000200012Q0017000E000C4Q000F000E000100012Q000A3Q00013Q00063Q00043Q0003063Q00747970656F6603073Q0067657467656E7603083Q0066756E6374696F6E03023Q005F47000C3Q0012333Q00013Q001233000100024Q00123Q000200020026253Q0009000100030004263Q000900010012333Q00024Q003A3Q0001000200061E3Q000A000100010004263Q000A00010012333Q00044Q00293Q00024Q000A3Q00017Q000A3Q0003063Q00747970656F6603023Q006F7303053Q007461626C6503043Q0074696D65028Q0003043Q006D61746803063Q0072616E646F6D025Q00408F40024Q008087C34003083Q00746F737472696E6700293Q0012333Q00013Q001233000100024Q00123Q000200020026253Q000E000100030004263Q000E00010012333Q00023Q0020245Q00040006313Q000E00013Q0004263Q000E00010012333Q00023Q0020245Q00042Q003A3Q0001000200061E3Q000F000100010004263Q000F000100122B3Q00053Q001233000100013Q001233000200064Q00120001000200020026250001001F000100030004263Q001F0001001233000100063Q0020240001000100070006310001001F00013Q0004263Q001F0001001233000100063Q00202400010001000700122B000200083Q00122B000300094Q003200010003000200061E00010020000100010004263Q0020000100122B000100053Q0012330002000A4Q001700036Q00120002000200020012330003000A4Q0017000400014Q00120003000200022Q002A0002000200032Q0029000200024Q000A3Q00017Q000B3Q0003063Q00747970656F6603043Q0067616D6503073Q00482Q747047657403083Q0066756E6374696F6E03053Q007063612Q6C03043Q007479706503063Q00737472696E67034Q0003073Q007265717565737403053Q007461626C6503043Q00426F647901443Q001233000100013Q001233000200023Q0020240002000200032Q001200010002000200262500010027000100040004263Q00270001001233000100053Q001233000200023Q0020240002000200032Q001700036Q000C000400014Q00410001000400020006310001001600013Q0004263Q00160001001233000300064Q0017000400024Q001200030002000200262500030016000100070004263Q0016000100264B00020016000100080004263Q001600012Q0029000200023Q001233000300053Q001233000400023Q0020240004000400032Q001700056Q00410003000500042Q0017000200044Q0017000100033Q0006310001002700013Q0004263Q00270001001233000300064Q0017000400024Q001200030002000200262500030027000100070004263Q0027000100264B00020027000100080004263Q002700012Q0029000200023Q001233000100013Q001233000200094Q001200010002000200262500010041000100040004263Q00410001001233000100053Q00060400023Q000100012Q00168Q00490001000200020006310001004100013Q0004263Q00410001001233000300064Q0017000400024Q0012000300020002002625000300410001000A0004263Q00410001001233000300063Q00202400040002000B2Q001200030002000200262500030041000100070004263Q0041000100202400030002000B00264B00030041000100080004263Q0041000100202400030002000B2Q0029000300024Q0037000100014Q0029000100024Q000A3Q00013Q00013Q00043Q0003073Q00726571756573742Q033Q0055726C03063Q004D6574686F642Q033Q0047455400083Q0012333Q00014Q003000013Q00022Q003E00025Q0010360001000200020030140001000300042Q00073Q00014Q00478Q000A3Q00017Q00083Q0003043Q007479706503063Q00737472696E67034Q002Q033Q00737562026Q00F03F026Q0008402Q033Q00EFBBBF026Q00104001143Q001233000100014Q001700026Q001200010002000200262500010007000100020004263Q000700010026253Q0008000100030004263Q000800012Q00293Q00023Q00200800013Q000400122B000300053Q00122B000400064Q003200010004000200262500010012000100070004263Q0012000100200800013Q000400122B000300084Q0007000100034Q004700016Q00293Q00024Q000A3Q00017Q00063Q0003043Q007479706503063Q00737472696E67034Q00030A3Q006C6F6164737472696E6703013Q004000021A4Q003E00026Q0017000300014Q00120002000200022Q0017000100023Q001233000200014Q0017000300014Q00120002000200020026250002000B000100020004263Q000B00010026250001000D000100030004263Q000D00012Q000C00026Q0029000200023Q001233000200044Q0017000300013Q00122B000400054Q001700056Q002A0004000400052Q003200020004000200262500020016000100060004263Q001600012Q000B00026Q000C000200014Q0017000300014Q0005000200034Q000A3Q00017Q00063Q0003063Q006970616972732Q033Q003F763D03053Q00652Q726F72031D3Q005B5343525D20D09DD0B520D181D0BAD0B0D187D0B0D0BBD181D18F3A20030A3Q0020286C6F61646572207603013Q002901204Q003E00016Q003A000100010002001233000200014Q003E000300014Q00490002000200040004263Q001500012Q0017000700064Q001700085Q00122B000900024Q0017000A00014Q002A00070007000A2Q003E000800024Q0017000900074Q00120008000200022Q003E000900034Q0017000A6Q0017000B00084Q00410009000B000A0006310009001500013Q0004263Q001500012Q0029000A00023Q00064A00020006000100020004263Q00060001001233000200033Q00122B000300044Q001700045Q00122B000500054Q003E000600043Q00122B000700064Q002A0003000300072Q00280002000200012Q000A3Q00017Q00", GetFEnv(), ...);