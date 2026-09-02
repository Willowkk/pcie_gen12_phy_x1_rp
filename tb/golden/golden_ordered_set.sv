package golden_ordered_set_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  typedef struct packed {
    logic                  valid;
    logic                  last;
    logic [7:0]            data;
    logic                  is_k;
    pcie_character_class_t char_class;
  } golden_os_symbol_t;

  function automatic int unsigned golden_os_length(input pcie_os_kind_t kind_i);
    case (kind_i)
      OS_KIND_TS1, OS_KIND_TS2, OS_KIND_EIEOS: return 16;
      OS_KIND_SKP, OS_KIND_FTS, OS_KIND_EIOS: return 4;
      default: return 0;
    endcase
  endfunction

  // PCIe Gen1/Gen2 reference, one character at a time. TS field bytes occupy
  // symbols 1..5 and ten identifier characters complete the 16-symbol TS.
  function automatic golden_os_symbol_t golden_os_symbol(
    input pcie_os_kind_t kind_i,
    input int unsigned index_i,
    input pcie_ts_fields_t fields_i
  );
    golden_os_symbol_t result;
    begin
      result = '0;
      result.valid = index_i < golden_os_length(kind_i);
      result.last = result.valid && (index_i + 1 == golden_os_length(kind_i));
      case (kind_i)
        OS_KIND_TS1, OS_KIND_TS2: begin
          result.char_class = CHAR_CLASS_TS;
          case (index_i)
            0: begin result.data = K_COM; result.is_k = 1'b1; end
            1: begin
              result.data = fields_i.link_num_is_pad ? K_PAD : fields_i.link_num;
              result.is_k = fields_i.link_num_is_pad;
            end
            2: begin
              result.data = fields_i.lane_num_is_pad ? K_PAD : {3'b000, fields_i.lane_num};
              result.is_k = fields_i.lane_num_is_pad;
            end
            3: result.data = fields_i.n_fts;
            // PCIe 2.1 TS Symbol 4: Gen1/Gen2 support are bits 1/2 and
            // speed-change is bit 7.  The project keeps speed-change in
            // training_ctrl[5], so the reference model performs that mapping
            // explicitly instead of copying the packed RTL field.
            4: result.data = {fields_i.training_ctrl[5], 4'b0000,
                              fields_i.rate_id[1], fields_i.rate_id[0], 1'b0};
            // TS Symbol 5 carries the remaining Training Control flags.
            5: result.data = {3'b000, fields_i.training_ctrl[4:0]};
            default: result.data = (kind_i == OS_KIND_TS2) ? D_TS2 : D_TS1;
          endcase
        end
        OS_KIND_SKP: begin
          result.char_class = CHAR_CLASS_SKP;
          result.data = (index_i == 0) ? K_COM : K_SKP;
          result.is_k = 1'b1;
        end
        OS_KIND_FTS: begin
          result.char_class = CHAR_CLASS_FTS;
          result.data = (index_i == 0) ? K_COM : K_FTS;
          result.is_k = 1'b1;
        end
        OS_KIND_EIOS: begin
          result.char_class = CHAR_CLASS_EIOS;
          result.data = (index_i == 0) ? K_COM : K_EIOS;
          result.is_k = 1'b1;
        end
        OS_KIND_EIEOS: begin
          result.char_class = CHAR_CLASS_EIEOS;
          // PCIe 2.1 Gen2 EIEOS is COM, fourteen K28.7 characters, D10.2.
          if (index_i == 0) begin
            result.data = K_COM;
            result.is_k = 1'b1;
          end else if (index_i == 15) begin
            result.data = D_TS1;
            result.is_k = 1'b0;
          end else begin
            result.data = K_EIE;
            result.is_k = 1'b1;
          end
        end
        default: result = '0;
      endcase
      return result;
    end
  endfunction

  function automatic logic [15:0] golden_os_pair_data(
    input pcie_os_kind_t kind_i,
    input int unsigned pair_index_i,
    input pcie_ts_fields_t fields_i
  );
    golden_os_symbol_t lo, hi;
    begin
      lo = golden_os_symbol(kind_i, pair_index_i * 2, fields_i);
      hi = golden_os_symbol(kind_i, pair_index_i * 2 + 1, fields_i);
      return {hi.data, lo.data};
    end
  endfunction

  function automatic logic [1:0] golden_os_pair_is_k(
    input pcie_os_kind_t kind_i,
    input int unsigned pair_index_i,
    input pcie_ts_fields_t fields_i
  );
    golden_os_symbol_t lo, hi;
    begin
      lo = golden_os_symbol(kind_i, pair_index_i * 2, fields_i);
      hi = golden_os_symbol(kind_i, pair_index_i * 2 + 1, fields_i);
      return {hi.is_k, lo.is_k};
    end
  endfunction

  function automatic logic golden_ts_fields_legal(
    input pcie_ts_fields_t fields_i,
    input logic expect_lane_zero_i
  );
    logic lane_ok;
    begin
      lane_ok = fields_i.lane_num_is_pad || !expect_lane_zero_i ||
                (fields_i.lane_num == 5'd0);
      return fields_i.valid && lane_ok && !$isunknown(fields_i.rate_id) &&
             !$isunknown(fields_i.training_ctrl);
    end
  endfunction
endpackage
