// -----------------------------------------------------------------------------
// 'dbg_guv_ctl' Register Definitions
// Revision: 4
// -----------------------------------------------------------------------------
// Generated on 2020-02-23 at 01:26 (UTC) by airhdl version 2020.02.1
// -----------------------------------------------------------------------------
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
// POSSIBILITY OF SUCH DAMAGE.
// -----------------------------------------------------------------------------

package dbg_guv_ctl_regs_pkg;

    // Revision number of the 'dbg_guv_ctl' register map
    localparam DBG_GUV_CTL_REVISION = 4;

    // Default base address of the 'dbg_guv_ctl' register map 
    localparam logic [31:0] DBG_GUV_CTL_DEFAULT_BASEADDR = 32'h00000000;
    
    // Register 'cmd_lo'
    localparam logic [31:0] CMD_LO_OFFSET = 32'h00000000; // address offset of the 'cmd_lo' register
    localparam CMD_LO_VALUE_BIT_OFFSET = 0; // bit offset of the 'value' field
    localparam CMD_LO_VALUE_BIT_WIDTH = 32; // bit width of the 'value' field
    localparam logic [31:0] CMD_LO_VALUE_RESET = 32'b00000000000000000000000000000000; // reset value of the 'value' field
    
    // Register 'cmd_hi'
    localparam logic [31:0] CMD_HI_OFFSET = 32'h00000004; // address offset of the 'cmd_hi' register
    localparam CMD_HI_VALUE_BIT_OFFSET = 0; // bit offset of the 'value' field
    localparam CMD_HI_VALUE_BIT_WIDTH = 32; // bit width of the 'value' field
    localparam logic [31:0] CMD_HI_VALUE_RESET = 32'b00000000000000000000000000000000; // reset value of the 'value' field

endpackage: dbg_guv_ctl_regs_pkg
