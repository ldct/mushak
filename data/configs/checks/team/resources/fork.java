
import java.util.Vector;
import java.lang.Thread;

class fork extends Thread {
  private String path;

  public static void main(String args[]) {
    fork f = new fork("");
  }
  
  fork(String path) {
    this.path=path;
    System.out.println(path);
    start();
  }

  public void run() {
    Vector children;
    int n;

    children = new Vector();
    for(n=1; children.add(new fork(path+"/"+n)) ; n++) {}
  }

}
