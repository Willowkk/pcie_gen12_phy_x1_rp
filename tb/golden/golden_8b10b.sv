package golden_8b10b_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  typedef struct packed {
    logic       legal;
    logic       rd_out;
    logic [9:0] code;
  } golden_enc_result_t;

  typedef struct packed {
    logic       code_error;
    logic       disparity_error;
    logic       is_k;
    logic       rd_out;
    logic [7:0] data;
  } golden_dec_result_t;

  function automatic logic golden_legal_k(input logic [7:0] data_i);
    logic [4:0] x;
    logic [2:0] y;
    begin
      x = data_i[4:0];
      y = data_i[7:5];
      return (x == 5'd28) || ((y == 3'd7) &&
             ((x == 5'd23) || (x == 5'd27) ||
              (x == 5'd29) || (x == 5'd30)));
    end
  endfunction

  // Entry layout is {toggles_disparity, complement_when_rd_plus,
  // rd_minus_code}. Values are the canonical IBM 5b/6b table.
  function automatic logic [7:0] golden_5b6b(input logic [5:0] index_i);
    begin
      case (index_i)
        6'd0:golden_5b6b=8'o371;  6'd1:golden_5b6b=8'o356;
        6'd2:golden_5b6b=8'o355;  6'd3:golden_5b6b=8'o043;
        6'd4:golden_5b6b=8'o353;  6'd5:golden_5b6b=8'o045;
        6'd6:golden_5b6b=8'o046;  6'd7:golden_5b6b=8'o107;
        6'd8:golden_5b6b=8'o347;  6'd9:golden_5b6b=8'o051;
        6'd10:golden_5b6b=8'o052; 6'd11:golden_5b6b=8'o013;
        6'd12:golden_5b6b=8'o054; 6'd13:golden_5b6b=8'o015;
        6'd14:golden_5b6b=8'o016; 6'd15:golden_5b6b=8'o372;
        6'd16:golden_5b6b=8'o366; 6'd17:golden_5b6b=8'o061;
        6'd18:golden_5b6b=8'o062; 6'd19:golden_5b6b=8'o023;
        6'd20:golden_5b6b=8'o064; 6'd21:golden_5b6b=8'o025;
        6'd22:golden_5b6b=8'o026; 6'd23:golden_5b6b=8'o327;
        6'd24:golden_5b6b=8'o363; 6'd25:golden_5b6b=8'o031;
        6'd26:golden_5b6b=8'o032; 6'd27:golden_5b6b=8'o333;
        6'd28:golden_5b6b=8'o034; 6'd29:golden_5b6b=8'o335;
        6'd30:golden_5b6b=8'o336; 6'd31:golden_5b6b=8'o365;
        6'd32:golden_5b6b=8'o374;
        default: golden_5b6b=8'o000;
      endcase
    end
  endfunction

  function automatic logic [7:0] golden_data_3b4b(input logic [3:0] index_i);
    begin
      case (index_i)
        4'd0:golden_data_3b4b=8'o315; 4'd1:golden_data_3b4b=8'o011;
        4'd2:golden_data_3b4b=8'o012; 4'd3:golden_data_3b4b=8'o103;
        4'd4:golden_data_3b4b=8'o313; 4'd5:golden_data_3b4b=8'o005;
        4'd6:golden_data_3b4b=8'o006; 4'd7:golden_data_3b4b=8'o307;
        4'd8:golden_data_3b4b=8'o316;
        default:golden_data_3b4b=8'o000;
      endcase
    end
  endfunction

  function automatic logic [7:0] golden_k_3b4b(input logic [2:0] index_i);
    begin
      case (index_i)
        3'd0:golden_k_3b4b=8'o315; 3'd1:golden_k_3b4b=8'o106;
        3'd2:golden_k_3b4b=8'o105; 3'd3:golden_k_3b4b=8'o103;
        3'd4:golden_k_3b4b=8'o313; 3'd5:golden_k_3b4b=8'o112;
        3'd6:golden_k_3b4b=8'o111; 3'd7:golden_k_3b4b=8'o316;
        default:golden_k_3b4b=8'o000;
      endcase
    end
  endfunction

  function automatic golden_enc_result_t golden_encode_8b10b(
    input logic [7:0] data_i,
    input logic is_k_i,
    input logic rd_i
  );
    golden_enc_result_t result;
    logic [4:0] x;
    logic [2:0] y;
    logic [7:0] entry6, entry4;
    logic [5:0] code6;
    logic [3:0] code4;
    logic rd_mid, use_alt7;
    begin
      x = data_i[4:0];
      y = data_i[7:5];
      result.legal = !is_k_i || golden_legal_k(data_i);
      entry6 = (is_k_i && (x == 5'd28)) ? golden_5b6b(6'd32)
                                                : golden_5b6b({1'b0, x});
      code6 = (rd_i && entry6[6]) ? ~entry6[5:0] : entry6[5:0];
      rd_mid = entry6[7] ^ rd_i;
      use_alt7 = (y == 3'd7) &&
                 ((rd_mid && ((x == 5'd11) || (x == 5'd13) || (x == 5'd14))) ||
                  (!rd_mid && ((x == 5'd17) || (x == 5'd18) || (x == 5'd20))));
      entry4 = is_k_i ? golden_k_3b4b(y)
                      : golden_data_3b4b(use_alt7 ? 4'd8 : {1'b0, y});
      code4 = (rd_mid && entry4[6]) ? ~entry4[3:0] : entry4[3:0];
      result.code = {code4, code6};
      result.rd_out = entry4[7] ^ rd_mid;
      if (!result.legal) begin
        result.code = 10'b0;
        result.rd_out = rd_i;
      end
      return result;
    end
  endfunction

  // A code found only for the opposite input RD is a disparity error; a code
  // absent from both legal spaces is a code error.
  function automatic golden_dec_result_t golden_decode_8b10b(
    input logic [9:0] code_i,
    input logic rd_i
  );
    golden_dec_result_t result;
    golden_enc_result_t candidate;
    integer data_index, k_index;
    logic found_current, found_opposite;
    begin
      result = '0;
      result.rd_out = rd_i;
      found_current = 1'b0;
      found_opposite = 1'b0;
      for (k_index = 0; k_index < 2; k_index = k_index + 1)
        for (data_index = 0; data_index < 256; data_index = data_index + 1) begin
          candidate = golden_encode_8b10b(data_index[7:0], k_index[0], rd_i);
          if (!found_current && candidate.legal && (candidate.code == code_i)) begin
            found_current = 1'b1;
            result.data = data_index[7:0];
            result.is_k = k_index[0];
            result.rd_out = candidate.rd_out;
          end
        end
      if (!found_current) begin
        for (k_index = 0; k_index < 2; k_index = k_index + 1)
          for (data_index = 0; data_index < 256; data_index = data_index + 1) begin
            candidate = golden_encode_8b10b(data_index[7:0], k_index[0], ~rd_i);
            if (!found_opposite && candidate.legal && (candidate.code == code_i)) begin
              found_opposite = 1'b1;
              result.data = data_index[7:0];
              result.is_k = k_index[0];
              result.rd_out = candidate.rd_out;
            end
          end
        if (found_opposite)
          result.disparity_error = 1'b1;
        else
          result.code_error = 1'b1;
      end
      return result;
    end
  endfunction

  function automatic logic golden_is_comma(input logic [7:0] data_i,
                                             input logic is_k_i);
    return is_k_i && (data_i == 8'hbc);
  endfunction
endpackage
